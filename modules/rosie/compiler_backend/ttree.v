module compiler_backend

import rosie.runtime as rt


// TTree  The first sibling of a tree (if there is one) is immediately after
// the tree. A reference to a second sibling (ps) is its position
// relative to the position of the tree itself.
struct TTree {
pub mut:
    tag TTag
    cap byte	  // kind of capture (if it is a capture)
    key int       // key in ktable for capture name (0 if no key); or key in charset table
    ps int        // occasional second sibling
    n int         // occasional counter
}

// If 'tree' is a 'char' pattern (TSet, TChar, TAny), convert it into a
// charset and return 1 else return 0.
fn (tree []TTree) has_charset(pos int) bool {
    elem := tree[pos]
    match elem.tag {
      .tset, .tchar, .tany {
          return true
      }
      else {
          return false
      }
    }
}

// If 'tree' is a 'char' pattern (TSet, TChar, TAny), convert it into a
// charset and return 1 else return 0.
fn (tree []TTree) to_charset(pos int) rt.Charset {
    elem := tree[pos]
    match elem.tag {
      .tset {  // copy set
          // TODO don't understand tree yet
          return rt.Charset{ /* data: tree[pos + 1] */ }
      }
      .tchar {   // only one char
          assert elem.n >= 0 && elem.n <= C.UCHAR_MAX
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
    ps := tree[pos].ps
    if ps == 0 { panic("Expected to find offset for sib2, but the offest (ps) is 0.") }
    return pos + ps
}

fn (tree []TTree) sib1(pos int) int {
    return pos + 1
}

// Check whether a pattern tree has captures
fn (tree []TTree) has_captures(pos int) bool {
    elem := tree[pos]
    match elem.tag {
      .tcapture, .truntime, .tbackref {
          return true
      }
      .tcall {
          return tree.has_captures(tree.sib2(pos))
      } else {
          x := elem.tag.numsiblings()
          if x == 1 {
              return tree.has_captures(tree.sib1(pos))
          } else if x == 2 {
              if tree.has_captures(tree.sib1(pos)) {
                  return true
              } else {
                  return tree.has_captures(tree.sib2(pos))
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
fn (tree []TTree) checkaux(pos int, pred PEOption) PEOption {
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
          return tree.checkaux(tree.sib1(pos), pred)
      }
      .truntime {  // can fail match empty iff body does
          panic("Did not expect to find .truntime")
          if pred == .penofail { return .penullable }
          return tree.checkaux(tree.sib1(pos), pred)
      }
      .tbackref {  // can fail can match empty iff referenced pattern can
          if pred == .penofail { return .penullable }
          return tree.checkaux(tree.sib1(pos), pred)
      }
      .tseq {
          if tree.checkaux(tree.sib1(pos), pred) == .penullable {
              return .penullable
          }
          return tree.checkaux(tree.sib2(pos), pred)
      }
      .tchoice {
          if tree.checkaux(tree.sib2(pos), pred) == .penofail {
              return .penofail
          }
          return tree.checkaux(tree.sib1(pos), pred)
      }
      .tcapture, .tgrammar, .trule {
          return tree.checkaux(tree.sib1(pos), pred)
      }
      .tcall {
          return tree.checkaux(tree.sib2(pos), pred)
      } else {
          panic("Should never happen")
      }
    }
}

// number of characters to match a pattern (or -1 if variable)
// ('count' avoids infinite loops for grammars)
fn (tree []TTree) fixedlenx(pos int, count int, len int) int {
    if count >= maxrules {
        panic("Exceeded the maximum of $maxrules .tcall invocations")
    }

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
          return tree.fixedlenx(tree.sib1(pos), count, len)
      }
      .tcall {
          return tree.fixedlenx(tree.sib2(pos), count + 1, len)
      }
      .tseq {
          xlen := tree.fixedlenx(tree.sib1(pos), count, len)
          if xlen < 0 { return -1 }
          return tree.fixedlenx(tree.sib2(pos), count, len)
      }
      .tchoice {
          n1 := tree.fixedlenx(tree.sib1(pos), count, len)
          if n1 < 0 { return -1 }
          n2 := tree.fixedlenx(tree.sib2(pos), count, len)
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
fn (tree []TTree) getfirst(pos int, follow rt.Charset, firstset rt.Charset) (int, rt.Charset) {
    elem := tree[pos]
    match elem.tag {
        .tchar, .tset, .tany {
            return 0, tree.to_charset(pos)
        }
        .ttrue {
            return 1, follow  // accepts the empty string
        }
        .tfalse {
            return 0, rt.new_charset(false)
        }
        .thalt {		// rosie
            return 1, follow
        }
        .tchoice {
            mut e1 := 0
            mut e2 := 0
            mut csaux := rt.new_charset(false)
            mut fs := rt.new_charset(false)
            e1, fs = tree.getfirst(tree.sib1(pos), follow, firstset)
            e2, csaux = tree.getfirst(tree.sib2(pos), follow, csaux)
            fs.merge_or(csaux)
            return e1 | e2, fs
        }
        .tseq {
            if tree.checkaux(tree.sib1(pos), .penullable) != .penullable {
                // when p1 is not nullable, p2 has nothing to contribute
                //  return getfirst(tree.sib1(pos), fullset, firstset)
                return tree.getfirst(tree.sib1(pos), fullset, firstset)
            }

            // FIRST(p1 p2, fl) = FIRST(p1, FIRST(p2, fl))
            mut e1 := 0
            mut e2 := 0
            mut csaux := rt.new_charset(false)
            mut fs := rt.new_charset(false)
            e2, csaux = tree.getfirst(tree.sib2(pos), follow, csaux)
            e1, fs = tree.getfirst(tree.sib1(pos), csaux, firstset)
            if e1 == 0 {    // 'e1' ensures that first can be used
                return 0, fs
            } else if (e1 | e2) & 2 != 0 {  // one of the children has a matchtime?
                return 2, fs  // pattern has a matchtime capture
            } else {      // else depends on 'e2'
                return e2, fs
            }
        }
        .trep {
            tree.getfirst(tree.sib1(pos), follow, firstset)
            return 1, follow  // accept the empty string
        }
        .tcapture, .tgrammar, .trule {
            return tree.getfirst(tree.sib1(pos), follow, firstset)
        }
        .truntime {  // function invalidates any follow info.
            panic("Should never happen")
        }
        .tbackref {  // future: maybe use first(referred_pattern) ?
            return 2, firstset	// treat this as a run-time capture
        }
        .tcall {
            // return getfirst(tree.sib2(), follow, firstset)
            return tree.getfirst(tree.sib2(pos), follow, firstset)
        }
        .tand {
            mut e := 0
            mut fs := rt.new_charset(false)
            e, fs = tree.getfirst(tree.sib1(pos), follow, firstset)
            fs.merge_and(follow)
            return e, fs
        }
        .tnot {
            if tree.has_charset(tree.sib1(pos)) {
                mut fs := tree.to_charset(tree.sib1(pos))
                fs.complement()
                return 1, fs
            }
            e, _ := tree.getfirst(tree.sib1(pos), follow, firstset)
            return e | 1, follow
        }
        .tbehind {  // instruction gives no new information
            // call 'getfirst' only to check for math-time captures
            e, _ := tree.getfirst(tree.sib1(pos), follow, firstset)
            return e | 1, follow  // always can accept the empty string
        }
        else {
            panic("Should never happen: $elem")
        }
    }
    panic("Should never happen: $elem")
}

/*
** If 'headfail(tree)' true, then 'tree' can fail only depending on the
** next character of the subject.
*/
fn (tree []TTree) headfail(pos int) bool {
    elem := tree[pos]
    match elem.tag {
      .tchar, .tset, .tany, .tfalse {
          return true
      }
      .ttrue, .trep, .truntime, .tnot, .tbehind, .thalt {	// rosie adds thalt
          return false
      }
      .tcapture, .tgrammar, .trule, .tand {
          return tree.headfail(tree.sib1(pos))
      }
      .tcall {
          return tree.headfail(tree.sib2(pos))
      }
      .tseq {
          if tree.sib2(pos) == 0 { return false }
          return tree.headfail(tree.sib1(pos))
      }
      .tchoice {
          if tree.headfail(tree.sib1(pos)) { return false }
          return tree.headfail(tree.sib2(pos))
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
fn (tree []TTree) needfollow(pos int) bool {
    elem := tree[pos]
    match elem.tag {
        .tchar, .tset, .tany, .tfalse, .ttrue, .tand, .tnot, .thalt,
        .truntime, .tbackref, .tgrammar, .tcall, .tbehind {
            return false
        }
        .tchoice, .trep {
            return true
        }
        .tcapture {
            return tree.needfollow(tree.sib1(pos))
        }
        .tseq {
            return tree.needfollow(tree.sib2(pos))
        } else {
            panic("Should never happen")
        }
    }
}
