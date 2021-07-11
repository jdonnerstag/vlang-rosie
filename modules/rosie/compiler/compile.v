module compiler

import rosie.runtime as rt

const (
    maxbehind = 0x7FFF	// INST_ADDR_MAX at most
    maxrules = 1_000
    fullset = rt.new_charset(true)
    noinst = -1
)

enum PEOption {
    penullable
    penofail
}

// Compiler state
struct CompileState {
pub mut:
    p Pattern       // pattern being compiled
    ncode int       // next position in p->code to be filled
    // lua_State *L
}

[inline]
fn (compst CompileState) getinst(i int) &rt.Slot {
    return &compst.p.code[i]
}

[inline]
fn (compst CompileState) get_last_inst() &rt.Slot {
    return &compst.p.code[compst.p.code.len - 1]
}

[inline]
fn (compst CompileState) get_inst_reverse(i int) &rt.Slot {
    return &compst.p.code[compst.p.code.len - 1 + i]
}

[inline]
fn (mut compst CompileState) addinstruction1(op rt.Opcode) {
    compst.p.code << rt.opcode_to_slot(op)
}

fn (mut compst CompileState) addinstruction(op rt.Opcode) int {
    if !(op in [rt.Opcode.set, rt.Opcode.span] || op.sizei() == 1) {
        panic("${@FILE}:${@LINE}: opcode $op (${op.name()})")
    }
    compst.addinstruction1( op)
    return compst.p.code.len - 1
}

fn (mut compst CompileState) set_ichar(c byte) {
    compst.p.code.last().set_char(c)
}

// TODO: refactor these addinstruction_xxxxx() functions
fn (mut compst CompileState) addinstruction_char(op rt.Opcode, c byte) {
    compst.addinstruction(op)
    compst.set_ichar(c)

    instr := compst.get_last_inst()
    assert instr.opcode() == op
    assert instr.ichar() == c
    assert instr.opcode() == .char || instr.sizei() == 1
}

fn (mut compst CompileState) set_index(k int) {
    compst.p.code.last().set_aux(k)
}

fn (mut compst CompileState) addinstruction_aux(op rt.Opcode, k int) {
    compst.addinstruction(op)
    compst.set_index(k)

    instr := compst.get_last_inst()
    assert instr.opcode() == op
    assert instr.aux() == k
    assert instr.sizei() == 1
}

fn (mut compst CompileState) add_addr(offset int) {
    compst.p.code << rt.Slot(offset)
}

fn (mut compst CompileState) addinstruction_offset(op rt.Opcode, offset int) int {
    compst.addinstruction1(op)
    compst.add_addr(offset)

    assert compst.get_inst_reverse(-1).opcode() == op
    assert compst.get_inst_reverse(-0) == rt.Slot(offset)
    assert op == .test_set || op.sizei() == 2

    return compst.p.code.len
}

// Add a capture instruction:
// 'op' is the capture instruction 'cap' the capture kind
// 'idx' the key into ktable
fn (mut compst CompileState) addinstcap(op rt.Opcode, cap int, idx int) {
    compst.addinstruction_offset(op, cap)
    compst.get_inst_reverse(-1).set_aux(idx)

    assert compst.get_inst_reverse(-1).aux() == idx
    assert (cap & 0xFFFFFF00) == 0   // ensure only 8 bits are being used
    assert (idx & 0xFF000000) == 0   // ensure only 24 bits are being used
}

fn (mut compst CompileState) gethere() int {
    return compst.p.code.len - 1
}

// Patch 'instruction' to jump to 'target'
fn (mut compst CompileState) jumptothere(i int, target int) {
    if i >= 0 {
        assert i != target
        compst.p.code[i] = rt.Slot(target - i)
    }
}

// Patch 'instruction' to jump to current position
fn (mut compst CompileState) jumptohere(i int) {
    compst.jumptothere(i, compst.gethere())
}

// Code an IChar instruction, or IAny if there is an equivalent
// test dominating it
fn (mut compst CompileState) codechar(c byte, tt int) int {
    inst := compst.getinst(tt)
    if tt >= 0 && inst.opcode() == .test_char && inst.ichar() == c {
        compst.addinstruction(.any)
    } else {
        compst.addinstruction_char(.char, c)
    }
    return tt
}

// Add a charset postfix to an instruction
fn (mut compst CompileState) addcharset(cs rt.Charset) {
    mut ptr := byteptr(cs.data.data)
    for _ in 0 .. rt.charset_inst_size {
        x := int(*ptr)
        compst.p.code << rt.Slot(x)
        unsafe { ptr = ptr + sizeof(x) }
    }
}

// code a char set, optimizing unit sets for IChar, "complete"
// sets for IAny, and empty sets for IFail also use an IAny
// when instruction is dominated by an equivalent test.
fn (mut compst CompileState) codecharset(cs rt.Charset, tt int) int {
    op, c := charsettype(cs)
    match op {
      .char {
          return compst.codechar(c, tt)
      }
      .set {  // non-trivial set?
          if tt >= 0 && compst.getinst(tt).opcode() == .test_set /* && cs.is_equal(rt.to_charset(compst.p.tree, tt + 1)) */ {
              compst.addinstruction(.any)
          } else {
              compst.addinstruction(.set)
              compst.addcharset(cs)
          }
      }
      else {
          compst.addinstruction_char(op, c)
      }
    }
    return tt
}

/*
** code a test set, optimizing unit sets for ITestChar, "complete"
** sets for ITestAny, and empty sets for IJmp (always fails).
** 'e' is true if test should accept the empty string. (Test
** instructions in the current VM never accept the empty string.)
*/
fn (mut compst CompileState) codetestset(cs rt.Charset, e int) bool {
    if e != 0 { return false } // no test

    op, c := charsettype(cs)
    match op {
      .fail {   // always jump
          compst.addinstruction_offset(.jmp, 0)
       }
      .any {
          compst.addinstruction_offset(.test_any, 0)
      }
      .char {
          compst.addinstruction_offset(.test_char, 0)
          compst.set_ichar(c)
          return true
      }
      .set {
          compst.addinstruction_offset(.test_set, 0)
          compst.addcharset(cs)
          return true
      }
      else {
          panic("Should never happen")
      }
    }
    return false
}

// Find the final destination of a sequence of jumps
fn finaltarget(code []rt.Slot, i int) int {
    for j in i .. code.len {
        if code[j].opcode() != .jmp { return j }
    }
    panic("Did not find an instruction following index $i that is not an .jmp")
}

// final label (after traversing any jumps)
fn finallabel(code []rt.Slot, i int) int {
    offset := int(code[i + 1])
    assert offset != 0
    return finaltarget(code, i + offset)
}

// <behind(p)> == behind n <p>   (where n = fixedlen(p))
fn (mut compst CompileState) codebehind(tree []TTree, pos int) ? {
    if tree[pos].n > 0 {
        compst.addinstruction_aux(.behind, tree[pos].n)
    }
    return compst.codegen(tree.sib1(pos), false, -1, fullset)
}

[inline]
fn (compst CompileState) is_codechoice(e1 int, pos1 int, pos2 int, fl rt.Charset, cs1 rt.Charset, cs2 rt.Charset) bool {
    if compst.p.tree.headfail(pos1) { return true }
    if e1 == 0 {
        compst.p.tree.getfirst(pos2, fl, cs2)
        if cs1.is_disjoint(cs2) { return true }
    }
    return false
}

/*
** Choice optimizations:
** - when p1 is headfail or
** when first(p1) and first(p2) are disjoint, than
** a character not in first(p1) cannot go to p1, and a character
** in first(p1) cannot go to p2 (at it is not in first(p2)).
** (The optimization is not valid if p1 accepts the empty string,
** as then there is no character at all...)
** - when p2 is empty and opt is true a IPartialCommit can reuse
** the Choice already active in the stack.
*/
fn (mut compst CompileState) codechoice(pos1 int, pos2 int, opt bool, fl rt.Charset) ? {
    haltp2 := compst.p.tree[pos2].tag == .thalt
    emptyp2 := compst.p.tree[pos2].tag == .ttrue

    mut cs1 := rt.new_charset(false)
    mut cs2 := rt.new_charset(false)
    mut e1 := 0
    e1, cs1 = compst.p.tree.getfirst(pos1, fullset, cs1)
    if haltp2 == false && compst.is_codechoice(e1, pos1, pos2, fl, cs1, cs2) {
        compst.codetestset(cs1, 0)
        test := compst.p.code.len - 1
        mut jmp := -1
        compst.codegen(pos1, false, test, fl)?
        if !emptyp2 {
            compst.addinstruction_offset(.jmp, 0)
            jmp = compst.p.code.len - 1
        }
        compst.jumptohere(test)
        compst.codegen(pos2, opt, -1, fl)?
        compst.jumptohere(jmp)
    } else if !haltp2 && opt && emptyp2 {
        // p1? == IPartialCommit p1
        compst.jumptohere(compst.addinstruction_offset(.partial_commit, 0))
        compst.codegen(pos1, true, -1, fullset)?
    } else {
        test := if compst.codetestset(cs1, e1) { compst.p.code.len } else { -1 }
        pchoice := compst.addinstruction_offset(.choice, 0)
        compst.codegen(pos1, emptyp2, test, fullset)?
        pcommit := compst.addinstruction_offset(.commit, 0)
        compst.jumptohere(pchoice)
        compst.jumptohere(test)
        compst.codegen(pos2, opt, -1, fl)?
        compst.jumptohere(pcommit)
    }
}

/*
** And predicate
** optimization: fixedlen(p) = n ==> <&p> == <p> behind n
** (valid only when 'p' has no captures)
*/
fn (mut compst CompileState) codeand(pos int, tt int) ?int {
    n := compst.p.tree.fixedlenx(pos, 0, 0)
    if n >= 0 && n <= maxbehind && !compst.p.tree.has_captures(pos) {
        compst.codegen(pos, false, tt, fullset)?
        if n > 0 {
            compst.addinstruction_aux(.behind, n)
        }
    } else {  // default: Choice L1 p1 BackCommit L2 L1: Fail L2:
        pchoice := compst.addinstruction_offset(.choice, 0)
        compst.codegen(pos, false, tt, fullset)?
        pcommit := compst.addinstruction_offset(.back_commit, 0)
        compst.jumptohere(pchoice)
        compst.addinstruction(.fail)
        compst.jumptohere(pcommit)
    }
    return 0			// Success
}

fn (mut compst CompileState) codecapture(pos int, tt int, fl rt.Charset) ?int {
    elem := compst.p.tree[pos]
    compst.addinstcap(.open_capture, elem.cap, elem.key)
    if false /* elem.cap == .Crosieconst */ {
        assert compst.p.tree[compst.p.tree.sib1(pos)].tag == .ttrue
        compst.addinstruction_aux(.close_const_capture, elem.n)
    } else {
        compst.codegen(compst.p.tree.sib1(pos), false, tt, fl)?
        compst.addinstruction(.close_capture)
    }
    return 0			// Success
}

fn (mut compst CompileState) codebackref(pos int) {
    compst.addinstruction_aux(.backref, compst.p.tree[pos].key)
}

/*
** Repetion optimizations:
** When pattern is a charset, can use special instruction ISpan.
** When pattern is head fail, or if it starts with characters that
** are disjoint from what follows the repetions, a simple test
** is enough (a fail inside the repetition would backtrack to fail
** again in the following pattern, so there is no need for a choice).
** When 'opt' is true, the repetion can reuse the Choice already
** active in the stack.
*/
fn (mut compst CompileState) coderep(pos int, opt bool, fl rt.Charset) ?int {
    if compst.p.tree.has_charset(pos) {
        st := compst.p.tree.to_charset(pos)
        compst.addinstruction(.span)
        compst.addcharset(st)
    } else {
        e1, st := compst.p.tree.getfirst(pos, fl, fullset)
        if compst.p.tree.headfail(pos) || (e1 == 0 && st.is_disjoint(fl)) {
            // L1: test (fail(p1)) -> L2 <p> jmp L1 L2: */
            compst.codetestset(st, 0)
            test := compst.p.code.len
            compst.codegen(0, false, test, fullset)?
            jmp := compst.addinstruction_offset(.jmp, 0)
            compst.jumptohere(test)
            compst.jumptothere(jmp, test)
        } else {
            /* test(fail(p1)) -> L2 choice L2 L1: <p> partialcommit L1 L2: */
            /* or (if 'opt'): partialcommit L1 L1: <p> partialcommit L1 */
            compst.codetestset(st, e1)
            test := compst.p.code.len
            mut pchoice := -1
            if opt {
                compst.jumptohere(compst.addinstruction_offset(.partial_commit, 0))
            } else {
                pchoice = compst.addinstruction_offset(.choice, 0)
            }
            l2 := compst.gethere()
            compst.codegen(pos, false, -1, fullset)?
            commit := compst.addinstruction_offset(.partial_commit, 0)
            compst.jumptothere(commit, l2)
            compst.jumptohere(pchoice)
            compst.jumptohere(test)
        }
    }
    return 0			// Success
}


/*
** Not predicate optimizations:
** In any case, if first test fails, 'not' succeeds, so it can jump to
** the end. If pattern is headfail, that is all (it cannot fail
** in other parts) this case includes 'not' of simple sets. Otherwise,
** use the default code (a choice plus a failtwice).
*/
fn (mut compst CompileState) codenot(pos int) ?int {
    e, st := compst.p.tree.getfirst(pos, fullset, fullset)
    compst.codetestset(st, e)
    test := compst.p.code.len
    if compst.p.tree.headfail(pos) {  // test (fail(p1)) -> L1 fail L1:
        compst.addinstruction(.fail)
    } else {
        // test(fail(p))-> L1 choice L1 <p> failtwice L1:
        pchoice := compst.addinstruction_offset(.choice, 0)
        compst.codegen(pos, false, -1, fullset)?
        compst.addinstruction(.fail_twice)
        compst.jumptohere(pchoice)
    }
    compst.jumptohere(test)
    return 0			// Success
}


/*
** change open calls to calls, using list 'positions' to find
** correct offsets also optimize tail calls
*/
fn (mut compst CompileState) correctcalls(positions []int, from int, to int) {
    for i := from; i < to; i += compst.getinst(i).sizei() {
        inst := compst.getinst(i)
        if inst.opcode() == .open_call {
            n := int(compst.p.code[i + 1])		  // rule number
            rulepos := positions[n]                 // rule position
            prev_inst := compst.getinst(rulepos - 1) // sizei(IRet) == 1
            assert rulepos == from || prev_inst.opcode() == .ret
            ft := finaltarget(compst.p.code, i + 2) // sizei(IOpenCall) == 2
            final_target := compst.getinst(ft)
            if final_target.opcode() == .ret {    // call ret ?
                compst.p.code[i] = rt.Slot(int(rt.Opcode.jmp))		          // tail call
            } else {
                compst.p.code[i] = rt.Slot(int(rt.Opcode.call))
            }
            compst.jumptothere(i, rulepos)  // call jumps to respective rule
            // verify (debugging)
            assert inst.opcode() == if final_target.opcode() == .ret { rt.Opcode.jmp } else { rt.Opcode.call }
            assert int(compst.p.code[i + 1]) == (rulepos - i)
            assert int(compst.p.code[i + 1]) != 0
        }
    }
}


/*
** Code for a grammar:
** call L1 jmp L2 L1: rule 1 ret rule 2 ret ... L2:
*/
fn (mut compst CompileState) codegrammar(pos int) ?int {
    mut positions := []int{ cap: maxrules }
    mut rulenumber := 0
    firstcall := compst.addinstruction_offset(.call, 0)  // call initial rule
    jumptoend := compst.addinstruction_offset(.jmp, 0)   // jump to the end
    start := compst.gethere()  // here starts the initial rule
    compst.jumptohere(firstcall)
    mut rule := 0
    for rule = compst.p.tree.sib1(pos); compst.p.tree[rule].tag == .trule; rule = compst.p.tree.sib2(rule) {
        positions[rulenumber] = compst.gethere()  // save rule position
        rulenumber ++
        compst.codegen(compst.p.tree.sib1(rule), false, -1, fullset)?  // code rule
        compst.addinstruction(.ret)
    }
    assert compst.p.tree[rule].tag == .ttrue
    compst.jumptohere(jumptoend)
    compst.correctcalls(positions, start, compst.gethere())
    return 0			// Success
}


fn (mut compst CompileState) codecall(pos int) {
    // offset is temporarily set to rule number (to be corrected later)
    compst.addinstruction_offset(.open_call, compst.p.tree[compst.p.tree.sib2(pos)].cap)
    assert compst.p.tree[compst.p.tree.sib2(pos)].tag == .trule
}

/*
** Code first child of a sequence
** (second child is called in-place to allow tail call)
** Return 'tt' for second child
*/
fn (mut compst CompileState) codeseq1(p1 int, p2 int, tt int, fl rt.Charset) ?int {
    if compst.p.tree.needfollow(p1) {
        _, fl1 := compst.p.tree.getfirst(p2, fl, fullset)  // p1 follow is p2 first
        compst.codegen(p1, false, tt, fl1)?
    } else  { // use 'fullset' as follow
        compst.codegen(p1, false, tt, fullset)?
    }

    if compst.p.tree.fixedlenx(p1, 0, 0) != 0 { // can 'p1' consume anything?
        return -1	   // invalidate test
    } else {
        return tt	   // else 'tt' still protects sib2
    }
}

/*
** Main code-generation function: dispatch to auxiliar functions
** according to kind of tree. ('needfollow' should return true
** only for constructions that use 'fl'.)
**
** code generation is recursive. 'opt' indicates that the code is being
** generated as the last thing inside an optional pattern (so, if that
** code is optional too, it can reuse the 'IChoice' already in place for
** the outer pattern). 'tt' points to a previous test protecting this
** code (or NOINST). 'fl' is the follow set of the pattern.
*/
fn (mut compst CompileState) codegen(pos int, opt bool, tt int, fl rt.Charset) ? {
    if pos < 0 || pos >= compst.p.tree.len {
        return error("compst.p.tree: Index out of range: i=$pos, a.len=$compst.p.tree.len")
    }

    elem := compst.p.tree[pos]
    match elem.tag {
      .tchar { compst.codechar(byte(elem.n), tt) }
      .tany { compst.addinstruction(.any) }
      .tset { compst.codecharset(fl, tt) }
      .ttrue { }
      .tfalse { compst.addinstruction(.fail) }
      .thalt { compst.addinstruction(.halt) }
      .tchoice { return compst.codechoice(compst.p.tree.sib1(pos), compst.p.tree.sib2(pos), opt, fl) }
      .trep { compst.coderep(compst.p.tree.sib1(pos), opt, fl)? }
      .tbehind { compst.codebehind(compst.p.tree, pos)? }
      .tnot { compst.codenot(compst.p.tree.sib1(pos))? }
      .tand { compst.codeand(compst.p.tree.sib1(pos), tt)? }
      .tcapture { compst.codecapture(pos, tt, fl)? }
      .tbackref { compst.codebackref(pos) }
      .tgrammar { compst.codegrammar(pos)? }
      .tcall { compst.codecall(pos) }
      .tseq {
          compst.codeseq1(compst.p.tree.sib1(pos), compst.p.tree.sib2(pos), tt, fl)?  // code 'p1'
          return compst.codegen(compst.p.tree.sib2(pos), opt, tt, fl)
      }
      .tnotree { return error("Did not expect .tnotree") }
      .truntime { return error("Did not expect .truntime") }
      else { return error("Did not expect '${elem.tag}' tag") }
    }
}

/*
** Optimize jumps and other jump-like instructions.
** 1) Update labels of instructions with labels to their final
** destinations (e.g., choice L1 ... L1: jmp L2: becomes choice L2)
** 2) Jumps to other instructions that do jumps become those
** instructions (e.g., jump to return becomes a return jump, and
** to commit becomes a commit)
*/
fn (mut compst CompileState) peephole() {
    mut i:= 0
    for i < compst.p.code.len {
        inst := compst.p.code[i]
        match inst.opcode() {
          // instructions with labels
          .partial_commit, .test_any, .call, .choice, .commit, .back_commit, .test_char, .test_set {
              final := finallabel(compst.p.code, i)
              compst.jumptothere(i, final)  // optimize label
          }
          .jmp {
              ft := finaltarget(compst.p.code, i)
              assert ft < compst.p.code.len
              target_inst := compst.p.code[ft]
              // switch on what this inst is jumping to
              match target_inst.opcode() {
                // instructions with unconditional implicit jumps
                .ret, .fail, .fail_twice, .halt, .end {
                    compst.p.code[i] = compst.p.code[ft]  // jump becomes that instruction
                    compst.p.code[i+1] = rt.Slot(int(rt.Opcode.any))    // 'no-op' for target position
                }
                .commit, .partial_commit, .back_commit { // inst. with unconditional explicit jumps
                    fft := finallabel(compst.p.code, ft)
                    assert fft < compst.p.code.len
                    compst.p.code[i] = compst.p.code[ft]  // jump becomes that instruction...
                    compst.jumptothere(i, fft)  // but must correct its offset
                    continue
                }
                .open_call {
                    panic("Found .iopencall during peephole optimization")
                }
                else {
                    compst.jumptothere(i, ft)  // optimize label
                }
              } // switch
          } // case IJmp
          .open_call {
              panic("found .iopencall during peephole optimization")
          }
          else {
              break
          }
        } // switch
        i += inst.sizei()
    } // for
    assert compst.p.code[i].opcode() == rt.Opcode.end
}

// Compile a pattern
fn compile(p Pattern) ?[]rt.Slot {
    mut compst := CompileState{ p: p }
    compst.codegen(0, false, -1, fullset)?
    compst.addinstruction(.end)
    compst.peephole()
    return p.code
}
