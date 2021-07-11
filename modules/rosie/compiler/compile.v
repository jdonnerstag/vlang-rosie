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

// Types of trees (stored in tree.tag)
enum TTag {
    tchar     // standard PEG elements
    tset      // standard PEG elements
    tany      // standard PEG elements
    ttrue
    tfalse
    trep
    tseq
    tchoice
    tnot
    tand
    tcall
    topencall
    trule      // sib1 is rule's pattern, sib2 is 'next' rule
    tgrammar   // sib1 is initial (and first) rule
    tbehind    // match behind
    tcapture   // regular capture
    truntime   // run-time capture
    tbackref   // Rosie: match previously captured text
    thalt      // Rosie: stop the vm (abend)
    tnotree    // Rosie: a compiled pattern restored from a file has no tree
}

// TTree  The first sibling of a tree (if there is one) is immediately after
// the tree. A reference to a second sibling (ps) is its position
// relative to the position of the tree itself.
struct TTree {
pub mut:
    tag TTag
    cap byte		  // kind of capture (if it is a capture)
    key int       // key in ktable for capture name (0 if no key)
    ps int        // occasional second sibling
    n int         // occasional counter
}

//
// A pattern constructed by the compiler has a tree and a ktable. (The
// ktable is a symbol table, and  a tree node that references a string
// holds an index into the ktable.)
//
// When a pattern is compiled, the code array is created.  A compiled
// pattern consists of its code and ktable.  These are written when a
// compiled pattern is saved to a file, and restored when loaded.
//
// A compiled pattern restored from a file has no tree.
//
struct Pattern {
pub mut:
    code []rt.Instruction
    kt rt.Ktable
    tree []TTree
}

fn (tag TTag) numsiblings() int {
    return match tag {
        .tchar { 0 }
        .tset { 0 }
        .tany { 0 }
        .ttrue { 0 }
        .tfalse { 0 }
        .trep { 1 }
        .tseq { 2 }
        .tchoice { 2 }
        .tnot { 1 }
        .tand { 1 }
        .tcall { 0 }
        .topencall { 0 }
        .trule { 2 }
        .tgrammar { 1 }
        .tbehind { 1 }
        .tcapture { 1 }
        .truntime { 1 }
        .tbackref { 0 }
        .thalt { 0 }
        .tnotree { 0 }
    }
}

// Check whether a charset is empty (returns IFail), singleton (IChar),
// full (IAny), or none of those (ISet). When singleton, '*c' returns
// which character it is. (When generic set, the set was the input,
// so there is no need to return it.)
fn charsettype(cs rt.Charset) (rt.Opcode, byte) {
    mut count := 0
    mut candidate := -1  // candidate position for the singleton char
    for i in 0 .. cs.data.len {  // for each byte
        b := cs.data[i]
        if b == 0 {  // is byte empty?
            if count > 1 {  // was set neither empty nor singleton?
                return rt.Opcode.set, byte(0)  // neither full nor empty nor singleton
            }
            // else set is still empty or singleton
        } else if b == 0xFF {  // is byte full?
            if count < (i * rt.bits_per_char) {  // was set not full?
                return rt.Opcode.set, byte(0)  // neither full nor empty nor singleton
            } else {
                count += rt.bits_per_char  // set is still full
            }
        } else if (b & (b - 1)) == 0 {  // has byte only one bit?
            if count > 0 {  // was set not empty?
                return rt.Opcode.set, byte(0)  // neither full nor empty nor singleton
            } else {    // set has only one char till now track it
                count ++
                candidate = i
            }
        } else {
            return rt.Opcode.set, byte(0)  // byte is neither empty, full, nor singleton
        }
    }

    if count == 0 {
        return rt.Opcode.fail, byte(0)  // empty set
    } else if count == 1 {  // singleton find character bit inside byte
        mut b := cs.data[candidate]
        mut ichar := candidate * rt.bits_per_char
        if (b & 0xF0) != 0 {
            ichar += 4
            b >>= 4
        }
        if (b & 0x0C) != 0 {
            ichar += 2
            b >>= 2
        }
        if (b & 0x02) != 0 {
            ichar += 1
        }
        return rt.Opcode.char, byte(ichar)
    } else {
        assert count == rt.charset_size * rt.bits_per_char  // full set
        return rt.Opcode.any, byte(0)
    }
}

// If 'tree' is a 'char' pattern (TSet, TChar, TAny), convert it into a
// charset and return 1 else return 0.
fn to_charset(tree []TTree, pos int) rt.Charset {
    elem := tree[pos]
    match elem.tag {
      .tset {  // copy set
          // TODO don#t understand tree yet
          return rt.Charset{ /* data: tree[pos + 1] */ }
      }
      .tchar {   // only one char
          assert 0 <= elem.n && elem.n <= C.UCHAR_MAX
          return rt.new_charset_with_byte(byte(elem.n))
      }
      .tany {    // add all characters to the set
          return fullset
      }
      else {
          panic("Expected one of .tset, .tchar, or .tany")
      }
    }
}

fn (tree []TTree) sib2(pos int) int {
    return pos + tree[pos].ps
}

fn (tree []TTree) sib1(pos int) int {
    return pos + 1
}

// Check whether a pattern tree has captures
fn has_captures(tree []TTree, pos int) bool {
    elem := tree[pos]
    match elem.tag {
      .tcapture, .truntime, .tbackref {
          return true
      }
      .tcall {
          return has_captures(tree, tree.sib2(pos))
      } else {
          x := elem.tag.numsiblings()
          if x == 1 {
              return has_captures(tree, tree.sib1(pos))
          } else if x == 2 {
              if has_captures(tree, tree.sib1(pos)) {
                  return true
              } else {
                  return has_captures(tree, tree.sib2(pos))
              }
          } else {
              assert elem.tag.numsiblings() == 0
              return false
          }
      }
    }
}

/*
** Checks how a pattern behaves regarding the empty string,
** in one of two different ways:
** A pattern is *nullable* if it can match without consuming any character
** A pattern is *nofail* if it never fails for any string
** (including the empty string).
** The difference is only for predicates and run-time captures
** for other patterns, the two properties are equivalent.
** (With predicates, &'a' is nullable but not nofail. Of course,
** nofail => nullable.)
** These functions are all convervative in the following way:
**    p is nullable => nullable(p)
**    nofail(p) => p cannot fail
** The function assumes that TOpenCall is not nullable
** this will be checked again when the grammar is fixed.
** Run-time captures can do whatever they want, so the result
** is conservative.
*/
fn checkaux(tree []TTree, pos int, pred PEOption) PEOption {
    elem := tree[pos]
    match elem.tag {
      .tchar, .tset, .tany, .tfalse, .topencall {
          return .penullable  // not nullable
      }
      .trep, .ttrue, .thalt {
          return .penofail  // no fail
      }
      .tnot, .tbehind {  // can match empty, but can fail
          return if pred == .penofail { PEOption.penullable } else { PEOption.penofail }
      }
      .tand {  // can match empty fail iff body does
          if pred == .penullable { return .penofail }
          return checkaux(tree, tree.sib1(pos), pred)
      }
      .truntime {  // can fail match empty iff body does
          assert false
          if pred == .penofail { return .penullable }
          return checkaux(tree, tree.sib1(pos), pred)
      }
      .tbackref {  // can fail can match empty iff referenced pattern can
          if pred == .penofail { return .penullable }
          return checkaux(tree, tree.sib1(pos), pred)
      }
      .tseq {
          if checkaux(tree, tree.sib1(pos), pred) == PEOption.penullable {
              return PEOption.penullable
          }
          return checkaux(tree, tree.sib2(pos), pred)
      }
      .tchoice {
          if checkaux(tree, tree.sib2(pos), pred) == PEOption.penofail {
              return PEOption.penofail
          }
          return checkaux(tree, tree.sib1(pos), pred)
      }
      .tcapture, .tgrammar, .trule {
          return checkaux(tree, tree.sib1(pos), pred)
      }
      .tcall {
          return checkaux(tree, tree.sib2(pos), pred)
      } else {
          panic("Should never happen")
      }
    }
}

// number of characters to match a pattern (or -1 if variable)
// ('count' avoids infinite loops for grammars)
fn fixedlenx(tree []TTree, pos int, count int, len int) int {
    if count >= maxrules { panic("Exceeded the maximum of $maxrules .tcall invocations") }

    elem := tree[pos]
    match elem.tag {
      .tchar, .tset, .tany {
          return len + 1
      }
      .tfalse, .ttrue, .tnot, .tand, .tbehind, .thalt {
          return len
      }
      .trep, .truntime, .topencall, .tbackref {
          return -1
      }
      .tcapture, .trule, .tgrammar {
          return fixedlenx(tree, tree.sib1(pos), count, len)
      }
      .tcall {
          return fixedlenx(tree, tree.sib2(pos), count + 1, len)
      }
      .tseq {
          xlen := fixedlenx(tree, tree.sib1(pos), count, len)
          if xlen < 0 { return -1 }
          return fixedlenx(tree, tree.sib2(pos), count, len)
      }
      .tchoice {
          n1 := fixedlenx(tree, tree.sib1(pos), count, len)
          if n1 < 0 { return -1 }
          n2 := fixedlenx(tree, tree.sib2(pos), count, len)
          return if n1 == n2 { n1 } else { -1 }
      }
      else {
          panic("Should never happen")
      }
    }
}

/*
** Computes the 'first set' of a pattern.
** The result is a conservative aproximation:
**   match p ax -> x (for some x) ==> a belongs to first(p)
** or
**   a not in first(p) ==> match p ax -> fail (for all x)
**
** The set 'follow' is the first set of what follows the
** pattern (full set if nothing follows it).
**
** The function returns 0 when this resulting set can be used for
** test instructions that avoid the pattern altogether.
** A non-zero return can happen for two reasons:
** 1) match p '' -> ''            ==> return has bit 1 set
** (tests cannot be used because they would always fail for an empty input)
** 2) there is a match-time capture ==> return has bit 2 set
** (optimizations should not bypass match-time captures).
*/
fn getfirst(tree []TTree, pos int, follow rt.Charset, firstset rt.Charset) (int, rt.Charset) {
    fs := first
    elem := tree[pos]
    match elem.tag {
        .tchar, .tset, .tany {
            to_charset(tree, firstset)
            return 0, firstset
        }
        .ttrue {
            firstset.copy(follow)
            return 1, firstset  // accepts the empty string
        }
        .tfalse {
            firstset = rt.new_charset(false)
            return 0, firstset
        }
        .thalt {		// rosie
            firstset.copy(follow)
            return 1, firstset
        }
        .tchoice {
            csaux := rt.new_charset(false)
            e1 := getfirst(tree, tree.sib1(pos), follow, firstset)
            e2 := getfirst(tree, tree.sib2(), follow, &csaux)
            firstset.merge_or(csaux)
            return e1 | e2, firstset
        }
        .tseq {
            if !nullable(tree.sib1(pos)) {
                // when p1 is not nullable, p2 has nothing to contribute
                //  return getfirst(tree.sib1(pos), fullset, firstset)
                return getfirst(tree, tree.sib1(pos), fullset, firstset)
            }

            // FIRST(p1 p2, fl) = FIRST(p1, FIRST(p2, fl))
              csaux := rt.new_charset(false)
              e2 := getfirst(tree, tree.sib2(), follow, csaux)
              e1 := getfirst(tree, tree.sib1(pos), csaux, firstset)
              if e1 == 0 {    // 'e1' ensures that first can be used
                  return 0, firstset
              } else if (e1 | e2) & 2 {  // one of the children has a matchtime?
                  return 2, firstset  // pattern has a matchtime capture
              } else {      // else depends on 'e2'
                  return e2, firstset
              }
        }
        .trep {
            getfirst(tree, tree.sib1(pos), follow, firstset)
            firstset.copy(follow)
            return 1, firstset  // accept the empty string
        }
        .tcapture, .tgrammar, .trule {
            return getfirst(tree, tree.sib1(pos), follow, firstset)
        }
        .truntime {  // function invalidates any follow info.
            panic("Should never happen")
        }
        .tbackref {  // future: maybe use first(referred_pattern) ?
            return 2, firstset	// treat this as a run-time capture
        }
        .tcall {
            // return getfirst(tree.sib2(), follow, firstset)
            return getfirst(tree, tree.sib2(pos), follow, firstset)
        }
        .tand {
            e = getfirst(tree, tree.sib1(pos), follow, firstset)
            firstset.merge_and(follow)
            return e, firstset
        }
        .tnot {
            if tocharset(tree, tree.sib1(pos), firstset) {
                firstset.complement()
                return 1, firstset
            }
            e := getfirst(tree, tree.sib1(pos), follow, firstset)
            firstset.copy(follow)  // uses follow
            return e | 1, firstset
        }
        .tbehind {  // instruction gives no new information
            // call 'getfirst' only to check for math-time captures
            e := getfirst(tree, tree.sib1(pos), follow, firstset)
            firstset.copy(follow)  // uses follow
            return e | 1, firstset  // always can accept the empty string
        }
        else {
            panic("Should never happen: $elem")
        }
    }
}

/*
** If 'headfail(tree)' true, then 'tree' can fail only depending on the
** next character of the subject.
*/
fn headfail(tree []TTree, pos int) bool {
    elem := tree[pos]
    match elem.tag {
      .tchar, .tset, .tany, .tfalse {
          return true
      }
      .ttrue, .trep, .truntime, .tnot, .tbehind, .thalt {	// rosie adds thalt
          return false
      }
      .tcapture, .tgrammar, .trule, .tand {
          return headfail(tree, tree.sib1(pos))
      }
      .tcall {
          return headfail(tree, tree.sib2(pos))
      }
      .tseq {
          if tree.sib2(pos) == 0 { return false }
          return headfail(tree, tree.sib1(pos))
      }
      .tchoice {
          if headfail(tree, tree.sib1(pos)) { return false }
          return headfail(tree, tree.sib2(pos))
      }
      .tbackref {
          return false
      } else {
          panic("Should never happen")
      }
    }
}

/*
** Check whether the code generation for the given tree can benefit
** from a follow set (to avoid computing the follow set when it is
** not needed)
*/
fn needfollow(tree []TTree, pos int) bool {
    elem := tree[pos]
    match elem.tag {
      .tchar, .tset, .tany, .tfalse, .ttrue, .tand, .tnot, .thalt, // rosie adds thalt
      .truntime, .tbackref, .tgrammar, .tcall, .tbehind {
          return false
      }
      .tchoice, .trep {
          return true
      }
      .tcapture {
          return needfollow(tree, tree.sib1(pos))
      }
      .tseq {
          return needfollow(tree, tree.sib2(pos))
      } else {
          panic("Should never happen")
      }
    }
}

// =======================================================
// Code generation
// =======================================================

// Compiler state
struct CompileState {
pub mut:
    p Pattern       // pattern being compiled
    ncode int       // next position in p->code to be filled
    // lua_State *L
}

[inline]
fn (compst CompileState) getinst(i int) rt.Instruction {
    return compst.p.code[i]
}

[inline]
fn (compst CompileState) get_last_inst() rt.Instruction {
    return compst.p.code.last()
}

[inline]
fn (compst CompileState) get_inst_reverse(i int) rt.Instruction {
    return compst.p.code[compst.p.code.len - 1 + i]
}

[inline]
fn (mut compst CompileState) addinstruction1(op rt.Opcode) {
    compst.p.code << rt.opcode_to_instruction(op)
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
    compst.p.code << rt.Instruction{ val: offset }
}

fn (mut compst CompileState) addinstruction_offset(op rt.Opcode, offset int) bool {
    compst.addinstruction1(op)
    compst.add_addr(offset)

    assert compst.get_inst_reverse(-1).opcode() == op
    assert compst.get_inst_reverse(-0).val == offset
    assert op == .test_set || op.sizei() == 2

    return true
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

fn (mut compst CompileState) gethere() int { return compst.p.code.len - 1 }

// Patch 'instruction' to jump to 'target'
fn (mut compst CompileState) jumptothere(i int, target int) {
    if i >= 0 {
        assert i != target
        compst.getinst(i).val = target - i
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
        compst.p.code << rt.Instruction{ val: x }
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
          if tt >= 0 && compst.getinst(tt).opcode() == .test_set && cs.is_equal(to_charset(compst.p.tree, tt + 1)) {
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
** 'e' is true iff test should accept the empty string. (Test
** instructions in the current VM never accept the empty string.)
*/
fn (mut compst CompileState) codetestset(cs rt.Charset, e int) bool {
    if e != 0 { return false } // no test

    op, c := charsettype(cs)
    match op {
      .fail { return compst.addinstruction_offset(.jmp, 0) } // always jump
      .any { return compst.addinstruction_offset(.test_any, 0) }
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
}

// Find the final destination of a sequence of jumps
fn finaltarget(code []rt.Instruction, i int) int {
    for j in i .. code.len {
        if code[j].opcode() != .jmp { return j }
    }
    panic("Did not find an instruction following index $i that is not an .jmp")
}

// final label (after traversing any jumps)
fn finallabel(code []rt.Instruction, i int) int {
    offset := code[i + 1].val
    assert offset != 0
    return finaltarget(code, i + offset)
}

// <behind(p)> == behind n <p>   (where n = fixedlen(p))
fn (mut compst CompileState) codebehind(tree []TTree, pos int) ? {
    if tree[pos].n > 0 {
        compst.addinstruction_aux(.behind, tree[pos].n)
    }
    return compst.codegen(tree, tree.sib1(pos), 0, -1, fullset)
}

[inline]
fn is_codechoice(haltp2 bool, p1 []TTree, pos1 int, p2 []TTree, pos2 int, fl rt.Charset, cs1 rt.Charset, cs2 rt.Charset) bool {
    if haltp2 == false {
        if headfail(p1, pos1) { return true }
        if !e1 {
            getfirst(p2, pos2, fl, cs2)
            if cs_disjoint(cs1, cs2) { return true }
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
fn (mut compst CompileState) codechoice(p1 []TTree, pos1 int, p2 []TTree, pos2 int, opt int, fl Charset) ? {
    haltp2 := p2[pos2].tag == .thalt
    emptyp2 := p2[pos2].tag == .ttrue

    cs1 := Charset{}
    cs2 := Charset{}
    e1 := getfirst(p1, pos1, fullset, cs1)
    if is_codechoice(haltp2, p1, pos1, p2, pos2, fl, cs1, cs2) {
        test := compst.codetestset(cs1, 0)
        mut jmp := -1
        compst.codegen(p1, 0, test, fl)?
        if !emptyp2 {
            jmp = compst.addinstruction_offset(.jmp, 0)
        }
        compst.jumptohere(test)
        compst.codegen(p2, opt, -1, fl)?
        compst.jumptohere(jmp)
    } else if !haltp2 && opt && emptyp2 {
        // p1? == IPartialCommit p1
        compst.jumptohere(compst.addinstruction_offset(.partial_commit, 0))
        compst.codegen(p1, 1, -1, fullset)?
    } else {
        test := compst.codetestset(cs1, e1)
        pchoice := compst.addinstruction_offset(.choice, 0)
        compst.codegen(p1, emptyp2, test, fullset)?
        pcommit = compst.addinstruction_offset(.commit, 0)
        compst.jumptohere(pchoice)
        compst.jumptohere(test)
        compst.codegen(p2, opt, -1, fl)?
        compst.jumptohere(pcommit)
    }
}

/*
** And predicate
** optimization: fixedlen(p) = n ==> <&p> == <p> behind n
** (valid only when 'p' has no captures)
*/
fn codeand(compst CompileState, tree TTree, tt int) int {
    n := fixedlen(tree)
    if n >= 0 && n <= maxbehind && !hascaptures(tree) {
        compst.codegen(tree, 0, tt, fullset)?
        if n > 0 {
            compst.addinstruction_aux(.ibehind, n)
        }
    } else {  // default: Choice L1 p1 BackCommit L2 L1: Fail L2:
        pchoice := compst.addinstruction_offset(.ichoice, 0)
        compst.codegen(tree, 0, tt, fullset)?
        pcommit = compst.addinstruction_offset(IBackCommit, 0)
        jumptohere(compst, pchoice)
        compst.addinstruction(.ifail)
        jumptohere(compst, pcommit)
    }
    return 0			// Success
}

fn codecapture(compst CompileState, tree TTree, int tt, fl Charset) int {
    addinstcap(compst, .iopencapture, tree.cap, tree.key)
    if tree.cap == Crosieconst {
        assert tree.sib1(pos).tag == .ttrue
        compst.addinstruction_aux(.icloseconstcapture, tree.n)
    } else {
        compst.codegen(tree.sib1(pos), 0, tt, fl)?
        compst.addinstruction(ICloseCapture)
    }
    return 0			// Success
}

fn codebackref(compst CompileState, tree TTree) {
    compst.addinstruction_aux(.ibackref, tree.key)
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
fn (mut compst CompileState) coderep(tree []TTree, pos int, opt int, fl Charset) int {
    st := Charset{}
    if to_charset(tree, mut st) {
        compst.addinstruction(rt.Opcode.ispan)
        compst.addcharset(st.cs)
    } else {
        e1 := getfirst(tree, fullset, st)
        if headfail(tree) || (!e1 && cs_disjoint(st, fl)) {
            // L1: test (fail(p1)) -> L2 <p> jmp L1 L2: */
            test := codetestset(compst, st, 0)
            compst.codegen(tree, 0, test, fullset)?
            jmp := compst.addinstruction_offset(rt.Opcode.ijmp, 0)
            jumptohere(compst, test)
            compst.jumptothere(jmp, test)
        } else {
            /* test(fail(p1)) -> L2 choice L2 L1: <p> partialcommit L1 L2: */
            /* or (if 'opt'): partialcommit L1 L1: <p> partialcommit L1 */
            test := codetestset(compst, st, e1)
            mut pchoice := -1
            if opt != 0 {
                jumptohere(compst, compst.addinstruction_offset(IPartialCommit, 0))
            } else {
                pchoice = compst.addinstruction_offset(rt.Opcode.ichoice, 0)
            }
            l2 := compst.gethere()
            compst.codegen(tree, 0, -1, fullset)?
            commit := compst.addinstruction_offset(IPartialCommit, 0)
            compst.jumptothere(commit, l2)
            jumptohere(compst, pchoice)
            jumptohere(compst, test)
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
fn codenot(compst CompileState, tree TTree) int {
    mut st := Charset{}
    e := getfirst(tree, fullset, mut st)
    test := codetestset(compst, st, e)
    if headfail(tree) {  // test (fail(p1)) -> L1 fail L1:
        compst.addinstruction(IFail)
    } else {
        // test(fail(p))-> L1 choice L1 <p> failtwice L1:
        pchoice := compst.addinstruction_offset(rt.Opcode.ichoice, 0)
        compst.codegen(tree, 0, -1, fullset)?
        compst.addinstruction(.ifailtwice)
        jumptohere(compst, pchoice)
    }
    jumptohere(compst, test)
    return 0			// Success
}


/*
** change open calls to calls, using list 'positions' to find
** correct offsets also optimize tail calls
*/
fn correctcalls(compst CompileState, positions []int, from int, to int) {
    for i := from; i < to; i += compst.getinst(i).sizei() {
        inst := compst.getinst(i)
        if inst.opcode() == .iopencall {
            n := addr(inst)			  // rule number
            rulepos := positions[n]                 // rule position
            prev_inst := compst.getinst(rulepos - 1) // sizei(IRet) == 1
            assert rulepos == from || opcode(prev_inst) == .iret
            ft := finaltarget(compst.p.code, i + 2) // sizei(IOpenCall) == 2
            final_target := compst.getinst(ft)
            if final_target.opcode() == .iret {    // call ret ?
                setopcode(inst, .ijmp)		          // tail call
            } else {
                setopcode(inst, .icall)
            }
            compst.jumptothere(i, rulepos)  // call jumps to respective rule
            // verify (debugging)
            assert inst.opcode() == if final_target.opcode() == .iret { .ijmp } else { .icall }
            assert addr(inst) == (rulepos - i)
            assert addr(inst) != 0
        }
    }
    assert i == to
}


/*
** Code for a grammar:
** call L1 jmp L2 L1: rule 1 ret rule 2 ret ... L2:
*/
fn codegrammar(compst CompileState, grammar TTree) int {
    mut positions := []int{ cap: maxrules }
    mut rulenumber := 0
    firstcall := compst.addinstruction_offset(.icall, 0)  // call initial rule
    jumptoend := compst.addinstruction_offset(IJmp, 0)   // jump to the end
    start := compst.gethere()  // here starts the initial rule
    jumptohere(compst, firstcall)
    for rule := sib1(grammar); rule.tag == .trule; rule = sib2(rule) {
        positions[rulenumber] = compst.gethere()  // save rule position
        rulenumber ++
        compst.codegen(sib1(rule), 0, -1, fullset)?  // code rule
        compst.addinstruction(.iret)
    }
    assert rule.tag == .ttrue
    jumptohere(compst, jumptoend)
    correctcalls(compst, positions, start, compst.gethere())
    return 0			// Success
}


fn codecall(compst CompileState, call TTree) {
    // offset is temporarily set to rule number (to be corrected later)
    compst.addinstruction_offset(.iopencall, sib2(call).cap)
    assert sib2(call).tag == .trule
}

/*
** Code first child of a sequence
** (second child is called in-place to allow tail call)
** Return 'tt' for second child
*/
fn codeseq1(compst CompileState, p1 TTree, p2 TTree, tt int, fl Charset) ?int {
    if needfollow(p1) {
        fl1 := Charset{}
        getfirst(p2, fl, mut fl1)  // p1 follow is p2 first
        compst.codegen(p1, 0, tt, fl1)?
    } else  { // use 'fullset' as follow
        compst.codegen(p1, 0, tt, fullset)?
    }

    if fixedlen(p1) != 0 { // can 'p1' consume anything?
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
fn (mut compst CompileState) codegen(tree_pos int, opt int, tt int, fl rt.Charset) ? {
    elem := compst.tree[pos]
    match elem.tag {
      .tchar { compst.codechar(elem.n, tt) }
      .tany { compst.addinstruction(.any) }
      .tset { compst.codecharset(treebuffer(tree), tt) }
      .ttrue { }
      .tfalse { compst.addinstruction(IFail) }
      .thalt { compst.addinstruction(IHalt) }
      .tchoice { return codechoice(compst, tree.sib1(pos), tree.sib2(), opt, fl) }
      .trep { return coderep(compst, tree.sib1(pos), opt, fl) }
      .tbehind { return codebehind(compst, tree) }
      .tnot { return codenot(compst, tree.sib1(pos)) }
      .tand { return codeand(compst, tree.sib1(pos), tt) }
      .tcapture { return codecapture(compst, tree, tt, fl) }
      .tbackref { codebackref(compst, tree) }
      .tgrammar { return codegrammar(compst, tree) }
      .tcall { codecall(compst, tree) }
      .tseq {
          codeseq1(compst, tree.sib1(pos), tree.sib2(), &tt, fl)?  // code 'p1'
          return compst.codegen(tree.sib2(), opt, tt, fl)
      }
      .tnotree { return error("Did not expect .tnotree") }
      .truntime { return error("Did not expect .truntime") }
      else { return error("Did not expect '${tree.tag.name()}' tag") }
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
          .ipartialcommit, .itestany, .icall, .ichoice, .icommit, .ibackcommit, .itestchar, .itestset {
              final := finallabel(compst.p.code, i)
              compst.jumptothere(i, final)  // optimize label
          }
          .ijmp {
              ft := finaltarget(compst.p.code, i)
              assert ft < compst.p.code.len
              target_inst = compst.p.code[ft]
              // switch on what this inst is jumping to
              match target_inst.opcode() {
                // instructions with unconditional implicit jumps
                .iret, .ifail, .ifailtwice, .ihalt, .iend {
                    compst.p.code[i] = compst.p.code[ft]  // jump becomes that instruction
                    compst.p.code[i+1].i.code = .iany    // 'no-op' for target position
                }
                .icommit, ipartialcommit, .ibackcommit { // inst. with unconditional explicit jumps
                    fft := finallabel(compst.p.code, ft)
                    assert fft < compst.p.code.len
                    compst.p.code[i] = compst.p.code[ft]  // jump becomes that instruction...
                    compst.jumptothere(i, fft)  // but must correct its offset
                    continue
                }
                .iopencall {
                    panic("Found .iopencall during peephole optimization")
                }
                else {
                    compst.jumptothere(i, ft)  // optimize label
                }
              } // switch
          } // case IJmp
          .iopencall {
              panic("found .iopencall during peephole optimization")
          }
          else {
              break
          }
        } // switch
        i += inst.sizei()
    } // for
    assert inst == NULL || inst.opcode() == .iend
}

// Compile a pattern
fn compile(p Pattern) ?[]rt.Instruction {
    compst := CompileState{ p: p }
    compst.codegen(p.tree, 0, -1, fullset)?
    compst.addinstruction(.iend)
    compst.peephole()
    return p.code
}
