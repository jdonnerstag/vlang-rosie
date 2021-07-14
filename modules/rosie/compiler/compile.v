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
    p &Pattern      // pattern being compiled
    ncode int       // next position in p->code to be filled
    // lua_State *L
    debug int       // The larger the more message
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

fn (mut compst CompileState) addinstruction_char(op rt.Opcode, c byte) {
    compst.p.code << rt.opcode_to_slot(op).set_char(c)
}

fn (mut compst CompileState) set_index(k int) {
    compst.p.code.last().set_aux(k)
}

fn (mut compst CompileState) addinstruction_aux(op rt.Opcode, k int) {
    compst.p.code << rt.opcode_to_slot(op).set_aux(k)
}

fn (mut compst CompileState) add_addr(offset int) {
    compst.p.code << rt.Slot(offset)
}

fn (mut compst CompileState) addinstruction_offset(op rt.Opcode, offset int) int {
    rtn := compst.p.code.len

    compst.p.code << rt.opcode_to_slot(op)
    compst.p.code << rt.Slot(offset)
    // TODO aux() would definitely be large enought for the offset as well.

    return rtn
}

// Add a capture instruction:
// 'op' is the capture instruction 'cap' the capture kind
// 'idx' the key into ktable
fn (mut compst CompileState) addinstcap(op rt.Opcode, cap int, idx int) {
    assert (cap & 0xFFFFFF00) == 0   // ensure only 8 bits are being used
    assert (idx & 0xFF000000) == 0   // ensure only 24 bits are being used

    compst.p.code << rt.opcode_to_slot(op).set_aux(idx)
    compst.p.code << rt.Slot(cap)
}

fn (mut compst CompileState) gethere() int {
    return compst.p.code.len - 1
}

// Patch 'instruction' to jump to 'target'
fn (mut compst CompileState) jumptothere(i int, target int) {
    assert i >= 0
    assert i != target

    // Patch the 'offset'
    compst.p.code[i + 1] = rt.Slot(target - i)
}

// Patch 'instruction' to jump to current position
fn (mut compst CompileState) jumptohere(i int) {
    compst.jumptothere(i, compst.gethere())
}

// Code an IChar instruction, or IAny if there is an equivalent
// test dominating it
fn (mut compst CompileState) codechar(c byte, tt int) int {
    if tt >= 0 {
        inst := compst.getinst(tt)
        if inst.opcode() == .test_char && inst.ichar() == c {
            compst.addinstruction(.any)
            return tt
        }
    }

    compst.addinstruction_char(.char, c)
    return tt
}

// Add a charset postfix to an instruction
fn (mut compst CompileState) addcharset(cs rt.Charset) {
    for ch in cs.data {
        compst.p.code << rt.Slot(ch)
    }
}

fn (compst CompileState) to_charset(pos int) rt.Charset {
    idx := compst.p.tree[pos].key
    return compst.p.charsets[idx]
}

// code a char set, optimizing unit sets for IChar, "complete"
// sets for IAny, and empty sets for IFail also use an IAny
// when instruction is dominated by an equivalent test.
fn (mut compst CompileState) codecharset(pos int, tt int) int {
    cs := compst.to_charset(pos)
    op, c := charsettype(cs)
    match op {
        .char {
            return compst.codechar(c, tt)
        }
        .set {  // non-trivial set?
            if tt >= 0 && compst.getinst(tt).opcode() == .test_set && cs.is_equal(compst.to_charset(tt)) {
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
            mut instr := rt.opcode_to_slot(.test_char)
            instr.set_char(c)
            compst.p.code << instr

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
fn (mut compst CompileState) codebehind(pos int) ? {
    elem := compst.p.tree[pos]
    assert elem.n >= 0

    if elem.n > 0 {
        compst.addinstruction_aux(.behind, elem.n)
    }
    return compst.codegen(compst.sib1(pos), false, -1, fullset)
}

[inline]
fn (compst CompileState) is_codechoice(e1 int, pos1 int, pos2 int, fl rt.Charset, cs1 rt.Charset, cs2 rt.Charset) bool {
    if compst.headfail(pos1) {
        if compst.debug > 2 { eprintln("is_codechoice: headfail == true") }
        return true
    }

    if e1 == 0 {
        if compst.debug > 2 { eprintln("is_codechoice: e1 == 0") }
        compst.getfirst(pos2, fl, cs2)
        if cs1.is_disjoint(cs2) {
            if compst.debug > 2 { eprintln("is_codechoice: $cs1 is disjoint $cs2") }
            return true
        }
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
fn (mut compst CompileState) codechoice(pos int, opt bool, fl rt.Charset) ? {
    elem := compst.p.tree[pos]
    assert elem.ps > 0

    pos1 := compst.sib1(pos)
    pos2 := compst.sib2(pos)
    elem2 := compst.p.tree[pos2]

    haltp2 := elem2.tag == .thalt
    emptyp2 := elem2.tag == .ttrue
    if compst.debug > 2 { eprintln("codechoice: pos=$pos, opt=$opt, pos1=$pos1, pos2=$pos2, haltp2=$haltp2, emptyp2=$emptyp2")}

    mut cs1 := rt.new_charset(false)
    mut cs2 := rt.new_charset(false)
    mut e1 := 0
    e1, cs1 = compst.getfirst(pos1, fullset, cs1)
    if haltp2 == false && compst.is_codechoice(e1, pos1, pos2, fl, cs1, cs2) {
        if compst.debug > 2 { eprintln("codechoice: 111") }
        test := compst.codelen()
        compst.codetestset(cs1, 0)
        mut jmp := -1
        compst.codegen(pos1, false, test, fl)?
        if !emptyp2 {
            jmp = compst.codelen()
            compst.addinstruction_offset(.jmp, 0)
        }
        compst.jumptohere(test)
        compst.codegen(pos2, opt, -1, fl)?
        compst.jumptohere(jmp)
    } else if !haltp2 && opt && emptyp2 {
        if compst.debug > 2 { eprintln("codechoice: 222") }
        // p1? == IPartialCommit p1
        compst.jumptohere(compst.addinstruction_offset(.partial_commit, 0))
        compst.codegen(pos1, true, -1, fullset)?
    } else {
        if compst.debug > 2 { eprintln("codechoice: 333") }
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
    pos1 := compst.sib1(pos)
    if false /* elem.cap == .Crosieconst */ {
        assert compst.p.tree[pos1].tag == .ttrue
        compst.addinstruction_aux(.close_const_capture, elem.n)
    } else {
        compst.codegen(pos1, false, tt, fl)?
        compst.addinstruction(.close_capture)
    }
    return 0			// Success
}

fn (mut compst CompileState) codebackref(pos int) {
    compst.addinstruction_aux(.backref, compst.p.tree[pos].key)
}

fn (compst CompileState) has_charset(pos int) bool {
    return compst.p.tree.has_charset(pos)
}

fn (compst CompileState) headfail(pos int) bool {
    return compst.p.tree.headfail(pos)
}

[inline]
fn (compst CompileState) codelen() int {
    return compst.p.code.len
}

/*
** Repetition optimizations:
** When pattern is a charset, can use special instruction ISpan.
** When pattern is head fail, or if it starts with characters that
** are disjoint from what follows the repetions, a simple test
** is enough (a fail inside the repetition would backtrack to fail
** again in the following pattern, so there is no need for a choice).
** When 'opt' is true, the repetion can reuse the Choice already
** active in the stack.
*/
fn (mut compst CompileState) coderep(pos int, opt bool, fl rt.Charset) ?int {
    if compst.debug > 2 { eprintln("coderep: pos=$pos, opt=$opt") }

    if compst.has_charset(pos) {
        st := compst.to_charset(pos)
        compst.addinstruction(.span)
        compst.addcharset(st)
    } else {
        e1, st := compst.getfirst(pos, fl, fullset)
        if compst.headfail(pos) || (e1 == 0 && st.is_disjoint(fl)) {
            if compst.debug > 2 { eprintln("coderep: headfail() == true && e1=$e1") }
            // L1: test (fail(p1)) -> L2 <p> jmp L1 L2: */
            test := compst.codelen()
            compst.codetestset(st, 0)
            if compst.debug > 2 { eprintln("coderep 111: test=$test") }
            compst.codegen(pos, false, test, fullset)?
            if compst.debug > 2 { eprintln("coderep 222") }
            jmp := compst.codelen()
            compst.addinstruction_offset(.jmp, 0)
            if compst.debug > 2 { eprintln("coderep 333: jmp=$jmp") }
            compst.jumptohere(test)
            if compst.debug > 2 { eprintln("coderep 444: jmp=$jmp, test=$test") }
            compst.jumptothere(jmp, test)
            if compst.debug > 2 { eprintln("coderep 555") }
        } else {
            if compst.debug > 2 { eprintln("coderep: false => headfail() ... ") }
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
    pos1 := compst.sib1(pos)
    e, st := compst.getfirst(pos1, fullset, fullset)
    test := compst.codelen()
    compst.codetestset(st, e)
    if compst.headfail(pos1) {  // test (fail(p1)) -> L1 fail L1:
        if compst.debug > 2 { eprintln("codenot 111: headfail()=true, pos=$pos, pos1=$pos1, test=$test") }
        compst.addinstruction(.fail)
    } else {
        if compst.debug > 2 { eprintln("codenot 222: headfail()=false, pos=$pos, pos1=$pos1, test=$test") }
        // test(fail(p))-> L1 choice L1 <p> failtwice L1:
        pchoice := compst.addinstruction_offset(.choice, 0)
        compst.codegen(pos1, false, -1, fullset)?
        compst.addinstruction(.fail_twice)
        compst.jumptohere(pchoice)
    }
    if compst.debug > 2 { eprintln("codenot 333: test=$test") }
    compst.jumptohere(test)
    return 0			// Success
}


/*
** change open calls to calls, using list 'positions' to find
** correct offsets also optimize tail calls
*/
fn (mut compst CompileState) correctcalls(positions []int, from int, to int) {
    if compst.debug > 2 { eprintln("correctcalls: positions.len=$positions.len") }

    for i := from; i < to; i += compst.getinst(i).sizei() {
        if compst.debug > 2 { eprintln("correctcalls 111: i=$i") }

        inst := compst.getinst(i)
        if inst.opcode() == .open_call {
            if compst.debug > 2 { eprintln("correctcalls 222: is .open_call") }

            n := int(compst.p.code[i + 1])		  // rule number
            rulepos := positions[n]                 // rule position
            prev_inst := compst.getinst(rulepos - 1) // sizei(IRet) == 1
            assert rulepos == from || prev_inst.opcode() == .ret
            ft := finaltarget(compst.p.code, i + 2) // sizei(IOpenCall) == 2
            final_target := compst.getinst(ft)
            if final_target.opcode() == .ret {    // call ret ?
                compst.p.code[i] = rt.opcode_to_slot(.jmp)		          // tail call
            } else {
                compst.p.code[i] = rt.opcode_to_slot(.call)
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
    if compst.debug > 2 { eprintln("codegrammar: pos=$pos") }

    mut positions := []int{}
    firstcall := compst.addinstruction_offset(.call, 0)  // call initial rule
    jumptoend := compst.addinstruction_offset(.jmp, 0)   // jump to the end
    start := compst.gethere()  // here starts the initial rule
    compst.jumptohere(firstcall)
    mut rule := compst.sib1(pos)
    for rule < compst.p.tree.len && compst.p.tree[rule].tag == .trule {
        if compst.debug > 2 { eprintln("codegrammar: rule=$rule") }

        positions << compst.gethere()  // save rule position
        compst.codegen(compst.sib1(rule), false, -1, fullset)?  // code rule
        compst.addinstruction(.ret)

        rule = compst.sib2(rule)
    }

    if compst.debug > 2 { eprintln("codegrammar: finishing. correctcalls") }
    compst.jumptohere(jumptoend)
    compst.correctcalls(positions, start, compst.gethere())
    return 0			// Success
}


fn (mut compst CompileState) codecall(pos int) {
    // offset is temporarily set to rule number (to be corrected later)
    compst.p.code << rt.opcode_to_slot(.open_call)
    compst.p.code << rt.Slot(0)

    //assert compst.p.tree[compst.p.tree.sib2(pos)].tag == .trule
}

fn (compst CompileState) needfollow(pos int) bool {
    return compst.p.tree.needfollow(pos)
}

fn (compst CompileState) getfirst(pos int, follow rt.Charset, firstset rt.Charset) (int, rt.Charset) {
    if compst.debug > 2 { eprintln("getfirst: pos=$pos, tag=${compst.p.tree[pos].tag}, follow=${follow.str()}, firstset=${firstset.str()}") }
    x, y := compst.p.tree.getfirst(pos, follow, firstset)
    if compst.debug > 2 { eprintln("getfirst returned: a=$x, cs=${y.str()}") }
    return x, y
}

fn (compst CompileState) fixedlenx(pos int, count int, len int) int {
    return compst.p.tree.fixedlenx(pos, count, len)
}

/*
** Code first child of a sequence
** (second child is called in-place to allow tail call)
** Return 'tt' for second child
*/
fn (mut compst CompileState) codeseq1(pos int, tt int, fl rt.Charset) ?int {
    p1 := compst.sib1(pos)
    eprintln("codeseq1: pos: $pos")
    if compst.needfollow(p1) {
        eprintln("follow sib-2")
        _, fl1 := compst.getfirst(compst.sib2(pos), fl, fullset)  // p1 follow is p2 first
        compst.codegen(p1, false, tt, fl1)?
    } else  { // use 'fullset' as follow
        eprintln("follow sib-1")
        compst.codegen(p1, false, tt, fullset)?
    }

    eprintln("fixedlenx: p1: $p1")
    if compst.fixedlenx(p1, 0, 0) != 0 { // can 'p1' consume anything?
        return -1	   // invalidate test
    } else {
        return tt	   // else 'tt' still protects sib2
    }
}

fn (compst CompileState) sib1(pos int) int {
    return compst.p.tree.sib1(pos)
}

fn (compst CompileState) sib2(pos int) int {
    return compst.p.tree.sib2(pos)
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
    if compst.debug > 2 { eprintln("codegen: pos=$pos, elem=$elem.tag, code.len=$compst.p.code.len") }
    match elem.tag {
        .tchar { compst.codechar(byte(elem.n), tt) }
        .tany { compst.addinstruction(.any) }
        .tset { compst.codecharset(pos, tt) }
        .ttrue { }
        .tfalse { compst.addinstruction(.fail) }
        .thalt { compst.addinstruction(.halt) }
        .tchoice { compst.codechoice(pos, opt, fl)? }
        .trep { compst.coderep(compst.sib1(pos), opt, fl)? }
        .tbehind { compst.codebehind(pos)? }
        .tnot { compst.codenot(pos)? }
        .tand { compst.codeand(compst.sib1(pos), tt)? }
        .tcapture { compst.codecapture(pos, tt, fl)? }
        .tbackref { compst.codebackref(pos) }
        .tgrammar { compst.codegrammar(pos)? }
        .tcall { compst.codecall(pos) }
        .tseq {
            assert compst.p.tree.len > (pos + 1)
            assert elem.ps > 0
            assert compst.p.tree.len > (pos + elem.ps)

            compst.codeseq1(pos, tt, fl)?  // code 'p1'
            return compst.codegen(compst.sib2(pos), opt, tt, fl)
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
              }
          }
          .open_call {
              panic("found .iopencall during peephole optimization")
          }
          .end {
              break
          }
          else {
              // ignore
          }
        }
        i += inst.sizei()
    }
}

// Compile a pattern
fn compile(p &Pattern, start_pos int, debug int) ?[]rt.Slot {
    if p.tree.len == 0 { return p.code }

    mut compst := CompileState{ p: p, debug: debug }
    compst.codegen(start_pos, false, -1, fullset)?
    compst.addinstruction(.end)
    compst.peephole()
    return p.code
}
