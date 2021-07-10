/*
** $Id: lpcode.c,v 1.23 2015/06/12 18:36:47 roberto Exp $
** Copyright 2007, Lua.org & PUC-Rio  (see 'lpeg.html' for license)
*/

#include <limits.h>


#include "lua.h"
#include "lauxlib.h"

#include "lptypes.h"
#include "lpcode.h"
#include "buf.h"
#include "rplx.h"
#include "vm.h"

/* signals a "no-instruction */
#define NOINST		-1



static const Charset fullset_ =
  {{0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF}};

static const Charset *fullset = &fullset_;

/*
** {======================================================
** Analysis and some optimizations
** =======================================================
*/

/*
** Check whether a charset is empty (returns IFail), singleton (IChar),
** full (IAny), or none of those (ISet). When singleton, '*c' returns
** which character it is. (When generic set, the set was the input,
** so there is no need to return it.)
*/
static Opcode charsettype (const byte *cs, int *c) {
  int count = 0;  /* number of characters in the set */
  int i;
  int candidate = -1;  /* candidate position for the singleton char */
  for (i = 0; i < CHARSETSIZE; i++) {  /* for each byte */
    int b = cs[i];
    if (b == 0) {  /* is byte empty? */
      if (count > 1)  /* was set neither empty nor singleton? */
        return ISet;  /* neither full nor empty nor singleton */
      /* else set is still empty or singleton */
    }
    else if (b == 0xFF) {  /* is byte full? */
      if (count < (i * BITSPERCHAR))  /* was set not full? */
        return ISet;  /* neither full nor empty nor singleton */
      else count += BITSPERCHAR;  /* set is still full */
    }
    else if ((b & (b - 1)) == 0) {  /* has byte only one bit? */
      if (count > 0)  /* was set not empty? */
        return ISet;  /* neither full nor empty nor singleton */
      else {  /* set has only one char till now; track it */
        count++;
        candidate = i;
      }
    }
    else return ISet;  /* byte is neither empty, full, nor singleton */
  }
  switch (count) {
    case 0: return IFail;  /* empty set */
    case 1: {  /* singleton; find character bit inside byte */
      int b = cs[candidate];
      *c = candidate * BITSPERCHAR;
      if ((b & 0xF0) != 0) { *c += 4; b >>= 4; }
      if ((b & 0x0C) != 0) { *c += 2; b >>= 2; }
      if ((b & 0x02) != 0) { *c += 1; }
      return IChar;
    }
    default: {
       assert(count == CHARSETSIZE * BITSPERCHAR);  /* full set */
       return IAny;
    }
  }
}


/*
** A few basic operations on Charsets
*/
static void cs_complement (Charset *cs) {
  loopset(i, cs->cs[i] = ~cs->cs[i]);
}

static int cs_equal (const byte *cs1, const byte *cs2) {
  loopset(i, if (cs1[i] != cs2[i]) return 0);
  return 1;
}

static int cs_disjoint (const Charset *cs1, const Charset *cs2) {
  loopset(i, if ((cs1->cs[i] & cs2->cs[i]) != 0) return 0;)
  return 1;
}


/*
** If 'tree' is a 'char' pattern (TSet, TChar, TAny), convert it into a
** charset and return 1; else return 0.
*/
int tocharset (TTree *tree, Charset *cs) {
  switch (tree->tag) {
    case TSet: {  /* copy set */
      loopset(i, cs->cs[i] = treebuffer(tree)[i]);
      return 1;
    }
    case TChar: {  /* only one char */
      assert(0 <= tree->u.n && tree->u.n <= UCHAR_MAX);
      loopset(i, cs->cs[i] = 0);  /* erase all chars */
      setchar(cs->cs, tree->u.n);  /* add that one */
      return 1;
    }
    case TAny: {
      loopset(i, cs->cs[i] = 0xFF);  /* add all characters to the set */
      return 1;
    }
    default: return 0;
  }
}


/*
** Check whether a pattern tree has captures
*/
int hascaptures (TTree *tree) {
 tailcall:
  switch (tree->tag) {
    case TCapture: case TRunTime: case TBackref:
      return 1;
    case TCall:
      tree = sib2(tree); goto tailcall;  /* return hascaptures(sib2(tree)); */
    case TOpenCall: assert(0);
    default: {
      switch (numsiblings[tree->tag]) {
        case 1:  /* return hascaptures(sib1(tree)); */
          tree = sib1(tree); goto tailcall;
        case 2:
          if (hascaptures(sib1(tree))) return 1;
          /* else return hascaptures(sib2(tree)); */
          tree = sib2(tree); goto tailcall;
        default: assert(numsiblings[tree->tag] == 0); return 0;
      }
    }
  }
}


/*
** Checks how a pattern behaves regarding the empty string,
** in one of two different ways:
** A pattern is *nullable* if it can match without consuming any character;
** A pattern is *nofail* if it never fails for any string
** (including the empty string).
** The difference is only for predicates and run-time captures;
** for other patterns, the two properties are equivalent.
** (With predicates, &'a' is nullable but not nofail. Of course,
** nofail => nullable.)
** These functions are all convervative in the following way:
**    p is nullable => nullable(p)
**    nofail(p) => p cannot fail
** The function assumes that TOpenCall is not nullable;
** this will be checked again when the grammar is fixed.
** Run-time captures can do whatever they want, so the result
** is conservative.
*/
int checkaux (TTree *tree, int pred) {
 tailcall:
  switch (tree->tag) {
    case TChar: case TSet: case TAny:
    case TFalse: case TOpenCall: 
      return 0;  /* not nullable */
    case TRep: case TTrue: case THalt: /* rosie adds THalt */
      return 1;  /* no fail */
    case TNot: case TBehind:  /* can match empty, but can fail */
      if (pred == PEnofail) return 0;
      else return 1;  /* PEnullable */
    case TAnd:  /* can match empty; fail iff body does */
      if (pred == PEnullable) return 1;
      /* else return checkaux(sib1(tree), pred); */
      tree = sib1(tree); goto tailcall;
    case TRunTime:  /* can fail; match empty iff body does */
      assert(0);
      if (pred == PEnofail) return 0;
      /* else return checkaux(sib1(tree), pred); */
      tree = sib1(tree); goto tailcall;
    case TBackref:  /* can fail; can match empty iff referenced pattern can */
      if (pred == PEnofail) return 0;
      /* else return checkaux(sib1(tree), pred); */
      tree = sib1(tree); goto tailcall;
    case TSeq:
      if (!checkaux(sib1(tree), pred)) return 0;
      /* else return checkaux(sib2(tree), pred); */
      tree = sib2(tree); goto tailcall;
    case TChoice:
      if (checkaux(sib2(tree), pred)) return 1;
      /* else return checkaux(sib1(tree), pred); */
      tree = sib1(tree); goto tailcall;
    case TCapture: case TGrammar: case TRule:
      /* return checkaux(sib1(tree), pred); */
      tree = sib1(tree); goto tailcall;
    case TCall:  /* return checkaux(sib2(tree), pred); */
      tree = sib2(tree); goto tailcall;
    default: assert(0); return 0;
  }
}


/*
** number of characters to match a pattern (or -1 if variable)
** ('count' avoids infinite loops for grammars)
*/
int fixedlenx (TTree *tree, int count, int len) {
 tailcall:
  switch (tree->tag) {
    case TChar: case TSet: case TAny:
      return len + 1;
    case TFalse: case TTrue: case TNot: case TAnd: case TBehind: case THalt: /* rosie adds THalt */
      return len;
    case TRep: case TRunTime: case TOpenCall: case TBackref:
      return -1;
    case TCapture: case TRule: case TGrammar:
      /* return fixedlenx(sib1(tree), count); */
      tree = sib1(tree); goto tailcall;
    case TCall:
      if (count++ >= MAXRULES)
        return -1;  /* may be a loop */
      /* else return fixedlenx(sib2(tree), count); */
      tree = sib2(tree); goto tailcall;
    case TSeq: {
      len = fixedlenx(sib1(tree), count, len);
      if (len < 0) return -1;
      /* else return fixedlenx(sib2(tree), count, len); */
      tree = sib2(tree); goto tailcall;
    }
    case TChoice: {
      int n1, n2;
      n1 = fixedlenx(sib1(tree), count, len);
      if (n1 < 0) return -1;
      n2 = fixedlenx(sib2(tree), count, len);
      if (n1 == n2) return n1;
      else return -1;
    }
    default: assert(0); return 0;
  };
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
** (tests cannot be used because they would always fail for an empty input);
** 2) there is a match-time capture ==> return has bit 2 set
** (optimizations should not bypass match-time captures).
*/
static int getfirst (TTree *tree, const Charset *follow, Charset *firstset) {
 tailcall:
  switch (tree->tag) {
    case TChar: case TSet: case TAny: {
      tocharset(tree, firstset);
      return 0;
    }
    case TTrue: {
      loopset(i, firstset->cs[i] = follow->cs[i]);
      return 1;  /* accepts the empty string */
    }
    case TFalse: {
      loopset(i, firstset->cs[i] = 0);
      return 0;
    }
    case THalt: {		/* rosie */
      loopset(i, firstset->cs[i] = follow->cs[i]); 
      return 1;
    }
    case TChoice: {
      Charset csaux;
      int e1 = getfirst(sib1(tree), follow, firstset);
      int e2 = getfirst(sib2(tree), follow, &csaux);
      loopset(i, firstset->cs[i] |= csaux.cs[i]);
      return e1 | e2;
    }
    case TSeq: {
      if (!nullable(sib1(tree))) {
        /* when p1 is not nullable, p2 has nothing to contribute;
           return getfirst(sib1(tree), fullset, firstset); */
        tree = sib1(tree); follow = fullset; goto tailcall;
      }
      else {  /* FIRST(p1 p2, fl) = FIRST(p1, FIRST(p2, fl)) */
        Charset csaux;
        int e2 = getfirst(sib2(tree), follow, &csaux);
        int e1 = getfirst(sib1(tree), &csaux, firstset);
        if (e1 == 0) return 0;  /* 'e1' ensures that first can be used */
        else if ((e1 | e2) & 2)  /* one of the children has a matchtime? */
          return 2;  /* pattern has a matchtime capture */
        else return e2;  /* else depends on 'e2' */
      }
    }
    case TRep: {
      getfirst(sib1(tree), follow, firstset);
      loopset(i, firstset->cs[i] |= follow->cs[i]);
      return 1;  /* accept the empty string */
    }
    case TCapture: case TGrammar: case TRule: {
      /* return getfirst(sib1(tree), follow, firstset); */
      tree = sib1(tree); goto tailcall;
    }
    case TRunTime: {  /* function invalidates any follow info. */
      assert(0);
      int e = getfirst(sib1(tree), fullset, firstset);
      if (e) return 2;  /* function is not "protected"? */
      else return 0;  /* pattern inside capture ensures first can be used */
    }
    case TBackref: {  /* FUTURE: maybe use first(referred_pattern) ?  */
      return 2;	      /* treat this as a run-time capture */
    }
    case TCall: {
      /* return getfirst(sib2(tree), follow, firstset); */
      tree = sib2(tree); goto tailcall;
    }
    case TAnd: {
      int e = getfirst(sib1(tree), follow, firstset);
      loopset(i, firstset->cs[i] &= follow->cs[i]);
      return e;
    }
    case TNot: {
      if (tocharset(sib1(tree), firstset)) {
        cs_complement(firstset);
        return 1;
      }
    } /* fallthrough */
    case TBehind: {  /* instruction gives no new information */
      /* call 'getfirst' only to check for math-time captures */
      int e = getfirst(sib1(tree), follow, firstset);
      loopset(i, firstset->cs[i] = follow->cs[i]);  /* uses follow */
      return e | 1;  /* always can accept the empty string */
    }
    default: assert(0); return 0;
  }
}


/*
** If 'headfail(tree)' true, then 'tree' can fail only depending on the
** next character of the subject.
*/
static int headfail (TTree *tree) {
 tailcall:
  switch (tree->tag) {
  case TChar: case TSet: case TAny: case TFalse:
    return 1;
  case TTrue: case TRep: case TRunTime: case TNot:
  case TBehind:  case THalt:	/* rosie adds THalt */
    return 0;
  case TCapture: case TGrammar: case TRule: case TAnd:
    tree = sib1(tree); goto tailcall;  /* return headfail(sib1(tree)); */
  case TCall:
    tree = sib2(tree); goto tailcall;  /* return headfail(sib2(tree)); */
  case TSeq:
    if (!nofail(sib2(tree))) return 0;
    /* else return headfail(sib1(tree)); */
    tree = sib1(tree); goto tailcall;
  case TChoice:
    if (!headfail(sib1(tree))) return 0;
    /* else return headfail(sib2(tree)); */
    tree = sib2(tree); goto tailcall;
  case TBackref:
    return 0;
    /* else return headfail(sib1(tree)); */
/*     tree = sib1(tree); goto tailcall; */
  default: assert(0); return 0;
  }
}


/*
** Check whether the code generation for the given tree can benefit
** from a follow set (to avoid computing the follow set when it is
** not needed)
*/
static int needfollow (TTree *tree) {
 tailcall:
  switch (tree->tag) {
    case TChar: case TSet: case TAny:
    case TFalse: case TTrue: case TAnd: case TNot: case THalt: /* rosie adds THalt */
    case TRunTime: case TBackref: case TGrammar: case TCall: case TBehind:
      return 0;
    case TChoice: case TRep:
      return 1;
    case TCapture:
      tree = sib1(tree); goto tailcall;
    case TSeq:
      tree = sib2(tree); goto tailcall;
    default: assert(0); return 0;
  } 
}

/* }====================================================== */



/*
** {======================================================
** Code generation
** =======================================================
*/

/*
** state for the compiler
*/
typedef struct CompileState {
  Pattern *p;  /* pattern being compiled */
  int ncode;  /* next position in p->code to be filled */
  lua_State *L;
} CompileState;

/*
** code generation is recursive; 'opt' indicates that the code is being
** generated as the last thing inside an optional pattern (so, if that
** code is optional too, it can reuse the 'IChoice' already in place for
** the outer pattern). 'tt' points to a previous test protecting this
** code (or NOINST). 'fl' is the follow set of the pattern.
*/
static int codegen (CompileState *compst, TTree *tree, int opt, int tt,
                     const Charset *fl);


void realloccode (lua_State *L, Pattern *p, int nsize) {
  void *ud;
  lua_Alloc f = lua_getallocf(L, &ud);
  void *newblock = f(ud, p->code, p->codesize * sizeof(Instruction),
                                  nsize * sizeof(Instruction));
  if (newblock == NULL && nsize > 0)
    luaL_error(L, "not enough memory");
  p->code = (Instruction *)newblock;
  p->codesize = nsize;
}


static int nextinstruction (CompileState *compst) {
  int size = compst->p->codesize;
  if (compst->ncode == size)
    realloccode(compst->L, compst->p, size * 2);
  return compst->ncode++;
}

#define getinstr(cs,i)		((cs)->p->code[i])

static int addinstruction1 (CompileState *compst, Opcode op) {
  int i = nextinstruction(compst);
  setopcode(&getinstr(compst, i), op);
  return i;
}

static int addinstruction (CompileState *compst, Opcode op) {
  int i = addinstruction1(compst, op); /* instruction */
  if (!((op==ISet) || (op==ISpan) || (sizei(&getinstr(compst, i)) == 1))) {
    printf("%s:%d: opcode %d (%s)\n", __FILE__, __LINE__, op, OPCODE_NAME(op));
    assert(0);
  }
  return i;
}

/* TODO: refactor these addinstruction_xxxxx() functions */
static int addinstruction_char (CompileState *compst, Opcode op, int c) {
  int i = addinstruction(compst, op); /* instruction */
  setichar(&getinstr(compst, i), c);
  assert(opcode(&getinstr(compst, i)) == op);
  assert(ichar(&getinstr(compst, i)) == (c & 0xFF));
  assert(!(c & 0xFFFFFF00));	/* ensure only 8 bits are being used */
  assert(sizei(&getinstr(compst, i)) == 1);
  if (!(op==IChar)) {
    printf("%s:%d: opcode %d (%s)\n", __FILE__, __LINE__, op, OPCODE_NAME(op));
    assert(0);
  }
  return i;
}

static int addinstruction_aux (CompileState *compst, Opcode op, int k) {
  int i = addinstruction(compst, op); /* instruction */
  setindex(&getinstr(compst, i), k);
  assert(opcode(&getinstr(compst, i)) == op);
  assert(index(&getinstr(compst, i)) == (k & 0xFFFFFF));
  assert(!(k & 0xFF000000));	/* ensure only 24 bits are being used */
  assert(sizei(&getinstr(compst, i)) == 1);
  return i;
}

static int addinstruction_offset (CompileState *compst, Opcode op, int offset) {
  int i = addinstruction1(compst, op);
  nextinstruction(compst);	/* space for offset */
  setaddr(&getinstr(compst, i), offset);
  assert(opcode(&getinstr(compst, i)) == op);
  assert(addr(&getinstr(compst, i)) == offset);
  if (! ((op == ITestSet) || (sizei(&getinstr(compst, i)) == 2)) ) {
    printf("%s:%d: opcode %d (%s)\n", __FILE__, __LINE__, op, OPCODE_NAME(op));
    assert(0);
  }
  return i;
}

/*
** Add a capture instruction:
** 'op' is the capture instruction; 'cap' the capture kind;
** 'idx' the key into ktable;
*/
static int addinstcap (CompileState *compst, Opcode op, int cap, int idx) {
  int i;
    i = addinstruction_offset(compst, op, cap);
    setindex(&getinstr(compst, i), idx);
    assert(index(&getinstr(compst, i)) == idx);
    assert(!(cap & 0xFFFFFF00)); /* ensure only 8 buts are being used */
    assert(!(idx & 0xFF000000)); /* ensure only 24 buts are being used */
    return i;
}

#define gethere(compst) 	((compst)->ncode)

/*
** Patch 'instruction' to jump to 'target'
*/
static void jumptothere (CompileState *compst, int instruction, int target) {
  if (instruction >= 0) {
    assert(target != instruction);
    int op = opcode(&getinstr(compst, instruction)); UNUSED(op);
    setaddr(&getinstr(compst, instruction), target - instruction);
    assert(opcode(&getinstr(compst, instruction)) == op);
    assert(addr(&getinstr(compst, instruction)) == (target - instruction));
  }
}

/*
** Patch 'instruction' to jump to current position
*/
static void jumptohere (CompileState *compst, int instruction) {
  jumptothere(compst, instruction, gethere(compst));
}

/*
** Code an IChar instruction, or IAny if there is an equivalent
** test dominating it
*/
static void codechar (CompileState *compst, int c, int tt) {
  Instruction *inst = &getinstr(compst, tt);
  if ((tt >= 0) && opcode(inst) == ITestChar && ichar(inst) == c)
    addinstruction(compst, IAny);
  else {
    addinstruction_char(compst, IChar, c);
  }
}

/*
** Add a charset postfix to an instruction
*/
static void addcharset (CompileState *compst, const byte *cs) {
  int p = gethere(compst);
  int i;
  /* make space for buffer */
  for (i = 0; i < (int)CHARSETINSTSIZE - 1; i++)
    nextinstruction(compst);
  /* fill buffer with charset */
  loopset(j, getinstr(compst, p).buff[j] = cs[j]);
}

/*
** code a char set, optimizing unit sets for IChar, "complete"
** sets for IAny, and empty sets for IFail; also use an IAny
** when instruction is dominated by an equivalent test.
*/
static void codecharset (CompileState *compst, const byte *cs, int tt) {
  int c = 0;  /* (=) to avoid warnings */
  Opcode op = charsettype(cs, &c);
  switch (op) {
    case IChar: codechar(compst, c, tt); break;
    case ISet: {  /* non-trivial set? */
      if (tt >= 0 && opcode(&getinstr(compst, tt)) == ITestSet &&
          cs_equal(cs, getinstr(compst, tt + 1).buff))
        addinstruction(compst, IAny);
      else {
        addinstruction(compst, ISet);
        addcharset(compst, cs);
      }
      break;
    }
  default: addinstruction_char(compst, op, c); break;
  }
}

/*
** code a test set, optimizing unit sets for ITestChar, "complete"
** sets for ITestAny, and empty sets for IJmp (always fails).
** 'e' is true iff test should accept the empty string. (Test
** instructions in the current VM never accept the empty string.)
*/
static int codetestset (CompileState *compst, Charset *cs, int e) {
  if (e) return NOINST;  /* no test */
  else {
    int c = 0;
    Opcode op = charsettype(cs->cs, &c);
    switch (op) {
    case IFail: return addinstruction_offset(compst, IJmp, 0);  /* always jump */
    case IAny: return addinstruction_offset(compst, ITestAny, 0);
    case IChar: {
      int i = addinstruction_offset(compst, ITestChar, 0);
      setichar(&getinstr(compst, i), c);
      return i;
    }
    case ISet: {
      int i = addinstruction_offset(compst, ITestSet, 0);
      addcharset(compst, cs->cs);
      return i;
    }
    default: assert(0); return 0;
    }
  }
}

/*
** Find the final destination of a sequence of jumps
*/
static int finaltarget (Instruction *code, int i) {
  Instruction *pc = &code[i];
  while (opcode(pc) == IJmp) pc += addr(pc);
  return pc - code;
}

/*
** final label (after traversing any jumps)
*/
static int finallabel (Instruction *code, int i) {
  Instruction *pc = &code[i];
  assert(addr(pc));
  return finaltarget(code, i + addr(pc));
}

/*
** <behind(p)> == behind n; <p>   (where n = fixedlen(p))
*/
static int codebehind (CompileState *compst, TTree *tree) {
  if (tree->u.n > 0)
    addinstruction_aux(compst, IBehind, tree->u.n);
  return codegen(compst, sib1(tree), 0, NOINST, fullset);
}


/*
** Choice; optimizations:
** - when p1 is headfail or
** when first(p1) and first(p2) are disjoint, than
** a character not in first(p1) cannot go to p1, and a character
** in first(p1) cannot go to p2 (at it is not in first(p2)).
** (The optimization is not valid if p1 accepts the empty string,
** as then there is no character at all...)
** - when p2 is empty and opt is true; a IPartialCommit can reuse
** the Choice already active in the stack.
*/
static int codechoice (CompileState *compst, TTree *p1, TTree *p2, int opt,
                        const Charset *fl) {
  int err;
  int haltp2 = (p2->tag == THalt);
  int emptyp2 = (p2->tag == TTrue);
  Charset cs1, cs2;
  int e1 = getfirst(p1, fullset, &cs1);
  if (!haltp2 && (headfail(p1) ||
		  (!e1 && (getfirst(p2, fl, &cs2), cs_disjoint(&cs1, &cs2))))) {
    /* <p1 / p2> == test (fail(p1)) -> L1 ; p1 ; jmp L2; L1: p2; L2: */
    int test = codetestset(compst, &cs1, 0);
    int jmp = NOINST;
    err = codegen(compst, p1, 0, test, fl);
    if (err) return err;
    if (!emptyp2)
      jmp = addinstruction_offset(compst, IJmp, 0); 
    jumptohere(compst, test);
    err = codegen(compst, p2, opt, NOINST, fl);
    if (err) return err;
    jumptohere(compst, jmp);
  }
  else if (!haltp2 && opt && emptyp2) {
    /* p1? == IPartialCommit; p1 */
    jumptohere(compst, addinstruction_offset(compst, IPartialCommit, 0));
    err = codegen(compst, p1, 1, NOINST, fullset);
    if (err) return err;
  }
  else {
    /* <p1 / p2> == 
        test(first(p1)) -> L1; choice L1; <p1>; commit L2; L1: <p2>; L2: */
    int pcommit;
    int test = codetestset(compst, &cs1, e1);
    int pchoice = addinstruction_offset(compst, IChoice, 0);
    err = codegen(compst, p1, emptyp2, test, fullset);
    if (err) return err;
    pcommit = addinstruction_offset(compst, ICommit, 0);
    jumptohere(compst, pchoice);
    jumptohere(compst, test);
    err = codegen(compst, p2, opt, NOINST, fl);
    if (err) return err;
    jumptohere(compst, pcommit);
  }
  return 0;			/* Success */
}


/*
** And predicate
** optimization: fixedlen(p) = n ==> <&p> == <p>; behind n
** (valid only when 'p' has no captures)
*/
static int codeand (CompileState *compst, TTree *tree, int tt) {
  int err;
  int n = fixedlen(tree);
  if (n >= 0 && n <= MAXBEHIND && !hascaptures(tree)) {
    err = codegen(compst, tree, 0, tt, fullset);
    if (err) return err;
    if (n > 0)
      addinstruction_aux(compst, IBehind, n);
  }
  else {  /* default: Choice L1; p1; BackCommit L2; L1: Fail; L2: */
    int pcommit;
    int pchoice = addinstruction_offset(compst, IChoice, 0);
    err = codegen(compst, tree, 0, tt, fullset);
    if (err) return err;
    pcommit = addinstruction_offset(compst, IBackCommit, 0);
    jumptohere(compst, pchoice);
    addinstruction(compst, IFail);
    jumptohere(compst, pcommit);
  }
  return 0;			/* Success */
}

static int codecapture (CompileState *compst, TTree *tree, int tt,
                         const Charset *fl) {
    addinstcap(compst, IOpenCapture, tree->cap, tree->key);
    if (tree->cap == Crosieconst) {
      assert(sib1(tree)->tag == TTrue);
      addinstruction_aux(compst, ICloseConstCapture, tree->u.n);
    }
    else {
      int err = codegen(compst, sib1(tree), 0, tt, fl);
      if (err) return err;
      addinstruction(compst, ICloseCapture);
    }
    return 0;			/* Success */
}

static void codebackref (CompileState *compst, TTree *tree) { 
  addinstruction_aux(compst, IBackref, tree->key);
}

/*
** Repetion; optimizations:
** When pattern is a charset, can use special instruction ISpan.
** When pattern is head fail, or if it starts with characters that
** are disjoint from what follows the repetions, a simple test
** is enough (a fail inside the repetition would backtrack to fail
** again in the following pattern, so there is no need for a choice).
** When 'opt' is true, the repetion can reuse the Choice already
** active in the stack.
*/
static int coderep (CompileState *compst, TTree *tree, int opt,
                     const Charset *fl) {
  Charset st;
  int err;
  if (tocharset(tree, &st)) {
    addinstruction(compst, ISpan);
    addcharset(compst, st.cs);
  }
  else {
    int e1 = getfirst(tree, fullset, &st);
    if (headfail(tree) || (!e1 && cs_disjoint(&st, fl))) {
      /* L1: test (fail(p1)) -> L2; <p>; jmp L1; L2: */
      int jmp;
      int test = codetestset(compst, &st, 0);
      err = codegen(compst, tree, 0, test, fullset);
      if (err) return err;
      jmp = addinstruction_offset(compst, IJmp, 0);
      jumptohere(compst, test);
      jumptothere(compst, jmp, test);
    }
    else {
      /* test(fail(p1)) -> L2; choice L2; L1: <p>; partialcommit L1; L2: */
      /* or (if 'opt'): partialcommit L1; L1: <p>; partialcommit L1; */
      int commit, l2;
      int test = codetestset(compst, &st, e1);
      int pchoice = NOINST;
      if (opt)
        jumptohere(compst, addinstruction_offset(compst, IPartialCommit, 0));
      else
        pchoice = addinstruction_offset(compst, IChoice, 0);
      l2 = gethere(compst);
      err = codegen(compst, tree, 0, NOINST, fullset);
      if (err) return err;
      commit = addinstruction_offset(compst, IPartialCommit, 0);
      jumptothere(compst, commit, l2);
      jumptohere(compst, pchoice);
      jumptohere(compst, test);
    }
  }
  return 0;			/* Success */
}


/*
** Not predicate; optimizations:
** In any case, if first test fails, 'not' succeeds, so it can jump to
** the end. If pattern is headfail, that is all (it cannot fail
** in other parts); this case includes 'not' of simple sets. Otherwise,
** use the default code (a choice plus a failtwice).
*/
static int codenot (CompileState *compst, TTree *tree) {
  Charset st;
  int e = getfirst(tree, fullset, &st);
  int test = codetestset(compst, &st, e);
  if (headfail(tree))  /* test (fail(p1)) -> L1; fail; L1:  */
    addinstruction(compst, IFail);
  else {
    /* test(fail(p))-> L1; choice L1; <p>; failtwice; L1:  */
    int pchoice = addinstruction_offset(compst, IChoice, 0);
    int err = codegen(compst, tree, 0, NOINST, fullset);
    if (err) return err;
    addinstruction(compst, IFailTwice);
    jumptohere(compst, pchoice);
  }
  jumptohere(compst, test);
  return 0;			/* Success */
}


/*
** change open calls to calls, using list 'positions' to find
** correct offsets; also optimize tail calls
*/
static void correctcalls (CompileState *compst, int *positions,
                          int from, int to) {
  int i;
  Instruction *inst, *prev_inst, *final_target;
  for (i = from; i < to; i += sizei(&getinstr(compst, i))) {
    inst = &getinstr(compst, i);
    //    printf("%4d %s\n", i, OPCODE_NAME(opcode(inst)));
    if (opcode(inst) == IOpenCall) {
      int n = addr(inst);			  /* rule number */
      int rulepos = positions[n];                 /* rule position */
      //printf("rule number from instruction: n = %d, rule position is %d\n", n, rulepos);
      prev_inst = &getinstr(compst, rulepos - 1); /* sizei(IRet) == 1 */
      assert(rulepos == from || opcode(prev_inst) == IRet); UNUSED(prev_inst);
      int ft = finaltarget(compst->p->code, i + 2); /* sizei(IOpenCall) == 2 */
      final_target = &getinstr(compst, ft);
      if (opcode(final_target) == IRet)	          /* call; ret ? */
        setopcode(inst, IJmp);		          /* tail call */
      else {
        setopcode(inst, ICall);
      }
      jumptothere(compst, i, rulepos);  /* call jumps to respective rule */
      /* verify (debugging) */
      assert(opcode(inst) == ((opcode(final_target)==IRet) ? IJmp : ICall));
      assert(addr(inst) == (rulepos - i));
      assert(addr(inst));
    }
  }
  assert(i == to);
}


/*
** Code for a grammar:
** call L1; jmp L2; L1: rule 1; ret; rule 2; ret; ...; L2:
*/
static int codegrammar (CompileState *compst, TTree *grammar) {
  int positions[MAXRULES];
  int rulenumber = 0;
  TTree *rule;
  int firstcall = addinstruction_offset(compst, ICall, 0);  /* call initial rule */
  int jumptoend = addinstruction_offset(compst, IJmp, 0);   /* jump to the end */
  int start = gethere(compst);  /* here starts the initial rule */
  jumptohere(compst, firstcall);
  for (rule = sib1(grammar); rule->tag == TRule; rule = sib2(rule)) {
    positions[rulenumber++] = gethere(compst);  /* save rule position */
    int err = codegen(compst, sib1(rule), 0, NOINST, fullset);  /* code rule */
    if (err) return err;
    addinstruction(compst, IRet);
  }
  assert(rule->tag == TTrue);
  jumptohere(compst, jumptoend);
  correctcalls(compst, positions, start, gethere(compst));
  return 0;			/* Success */
}


static void codecall (CompileState *compst, TTree *call) {
  /* offset is temporarily set to rule number (to be corrected later) */
  addinstruction_offset(compst, IOpenCall, sib2(call)->cap);
  assert(sib2(call)->tag == TRule);
}

/*
** Code first child of a sequence
** (second child is called in-place to allow tail call)
** Return 'tt' for second child
*/
static int codeseq1 (CompileState *compst, TTree *p1, TTree *p2,
                     int *tt, const Charset *fl) {
  int err;
  if (needfollow(p1)) {
    Charset fl1;
    getfirst(p2, fl, &fl1);  /* p1 follow is p2 first */
    err = codegen(compst, p1, 0, *tt, &fl1);
    if (err) return err;
  } else  { /* use 'fullset' as follow */
    err = codegen(compst, p1, 0, *tt, fullset);
    if (err) return err;
  }
  if (fixedlen(p1) != 0) { /* can 'p1' consume anything? */
    *tt = NOINST;  /* invalidate test */
    return 0;	   /* Success */
  } else {
    /* else 'tt' still protects sib2 */
    return 0;	   /* Success */
  }
}


/*
** Main code-generation function: dispatch to auxiliar functions
** according to kind of tree. ('needfollow' should return true
** only for consructions that use 'fl'.)
*/
static int codegen (CompileState *compst, TTree *tree, int opt, int tt,
                     const Charset *fl) {
  int err;
 tailcall:
  assert(tree != NULL);
  switch (tree->tag) {
  case TChar: codechar(compst, tree->u.n, tt); break;
  case TAny: addinstruction(compst, IAny); break;
  case TSet: codecharset(compst, treebuffer(tree), tt); break;
  case TTrue: break;
  case TFalse: addinstruction(compst, IFail); break;
  case THalt: addinstruction(compst, IHalt); break; /* rosie */
  case TChoice: return codechoice(compst, sib1(tree), sib2(tree), opt, fl); break;
  case TRep: return coderep(compst, sib1(tree), opt, fl); break;
  case TBehind: return codebehind(compst, tree); break;
  case TNot: return codenot(compst, sib1(tree)); break;
  case TAnd: return codeand(compst, sib1(tree), tt); break;
  case TCapture: return codecapture(compst, tree, tt, fl); break;
  case TBackref: codebackref(compst, tree); break;
  case TGrammar: return codegrammar(compst, tree); break;
  case TCall: codecall(compst, tree); break;
  case TSeq: {
    err = codeseq1(compst, sib1(tree), sib2(tree), &tt, fl);  /* code 'p1' */
    if (err) return err;
    /* codegen(compst, p2, opt, tt, fl); */
    tree = sib2(tree); goto tailcall;
  }
  case TNoTree: return 1;	/* TODO: create an enumeration for codegen error codes */
  case TRunTime: return 2;
  default: return 3;
  }
  return 0;			/* Success */
}


/*
** Optimize jumps and other jump-like instructions.
** * Update labels of instructions with labels to their final
** destinations (e.g., choice L1; ... L1: jmp L2: becomes
** choice L2)
** * Jumps to other instructions that do jumps become those
** instructions (e.g., jump to return becomes a return; jump
** to commit becomes a commit)
*/
static void peephole (CompileState *compst) {
  Instruction *code = compst->p->code;
  Instruction *target_inst, *inst = NULL;
  int i;
  for (i = 0; i < compst->ncode; i += sizei(&code[i])) {
   redo:
    inst = &code[i];
    switch (opcode(inst)) {
      /* instructions with labels */
    case IPartialCommit: case ITestAny:
    case ICall: case IChoice:
    case ICommit: case IBackCommit: 
    case ITestChar: case ITestSet: {
      int final = finallabel(code, i);
      jumptothere(compst, i, final);  /* optimize label */
      break;
    }
    case IJmp: {
      int ft = finaltarget(code, i);
      assert( ft < compst->ncode );
      target_inst = &code[ft];
      /* switch on what this inst is jumping to */
      switch (opcode(target_inst)) {
	/* instructions with unconditional implicit jumps */
      case IRet: case IFail: case IFailTwice:
      case IHalt: case IEnd: {
	code[i] = code[ft];  /* jump becomes that instruction */
	code[i+1].i.code = IAny;    /* 'no-op' for target position */
	break;
      }
      case ICommit: case IPartialCommit:
      case IBackCommit: { /* inst. with unconditional explicit jumps */
	int fft = finallabel(code, ft);
	assert( fft < compst->ncode );
	code[i] = code[ft];  /* jump becomes that instruction... */
	jumptothere(compst, i, fft);  /* but must correct its offset */
	goto redo;  /* reoptimize its label */
      }
      case IOpenCall: {
	assert(0); //LOG("found IOpenCall during peephole optimization\n");
      }
      default: {
	jumptothere(compst, i, ft);  /* optimize label */
	break;
      }} /* switch */
      break;
    } /* case IJmp */
    case IOpenCall: {
      assert(0); // LOG("found IOpenCall during peephole optimization\n");
    }
    default: break;
    } /* switch */
  } /* for */
  assert((inst == NULL) || (opcode(inst) == IEnd));
}

/*
** Compile a pattern
*/
Instruction *compile (lua_State *L, Pattern *p) {
  CompileState compst;
  compst.p = p;  compst.ncode = 0;  compst.L = L;
  realloccode(L, p, 2);  /* minimum initial size */
  if (codegen(&compst, p->tree, 0, NOINST, fullset)) return NULL;
  addinstruction(&compst, IEnd);
  realloccode(L, p, compst.ncode);  /* set final size */
  peephole(&compst);    
  return p->code;
}


/* }====================================================== */

