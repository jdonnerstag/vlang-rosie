/*  
** $Id: lptree.h,v 1.2 2013/03/24 13:51:12 roberto Exp $
*/

#if !defined(lptree_h)
#define lptree_h


#include "config.h"
#include "lptypes.h" 
#include "ktable.h"

/* number of siblings for each tree */
static const byte numsiblings[] = {
  0, 0, 0,	/* char, set, any */
  0, 0,		/* true, false */	
  1,		/* rep */
  2, 2,		/* seq, choice */
  1, 1,		/* not, and */
  0, 0, 2, 1,  /* call, opencall, rule, grammar */
  1,	       /* behind */
  1, 1,	       /* capture, runtime capture */
  0,	       /* Rosie backreference */
  0, 0,	       /* Rosie halt, no tree */
};

/*
** Types of trees (stored in tree->tag)
*/
typedef enum TTag {
  TChar = 0, TSet, TAny,  /* standard PEG elements */
  TTrue, TFalse,
  TRep,
  TSeq, TChoice,
  TNot, TAnd,
  TCall,
  TOpenCall,
  TRule,     /* sib1 is rule's pattern, sib2 is 'next' rule */
  TGrammar,  /* sib1 is initial (and first) rule */
  TBehind,   /* match behind */
  TCapture,  /* regular capture */
  TRunTime,  /* run-time capture */
  TBackref,  /* Rosie: match previously captured text */
  THalt,     /* Rosie: stop the vm (abend) */
  TNoTree,   /* Rosie: a compiled pattern restored from a file has no tree */
} TTag;

/*
 * Trees
 * The first sibling of a tree (if there is one) is immediately after
 * the tree.  A reference to a second sibling (ps) is its position
 * relative to the position of the tree itself.  
 *
 * The original lpeg implementation stated: "A key in ktable uses the
 * (unique) address of the original tree that created that entry. NULL
 * means no data." Now, a ktable key is merely a positive integer.
 * But perhaps the original comment will help explain some odd bit of
 * code that remains from lpeg.
 *
 */
typedef struct TTree {
  byte tag;
  byte cap;		/* kind of capture (if it is a capture) */
  int32_t key;		/* key in ktable for capture name (0 if no key) */
  union {
    int ps;		/* occasional second sibling */
    int n;		/* occasional counter */
  } u;
} TTree;


/*
 * A pattern constructed by the compiler has a tree and a ktable. (The
 * ktable is a symbol table, and  a tree node that references a string
 * holds an index into the ktable.)
 * 
 * When a pattern is compiled, the code array is created.  A compiled
 * pattern consists of its code and ktable.  These are written when a
 * compiled pattern is saved to a file, and restored when loaded.
 *
 * A compiled pattern restored from a file has no tree.
 */
typedef struct Pattern {
  union Instruction *code;
  int codesize;
  Ktable *kt;
  TTree tree[1];		/* tree must be last, because it will grow */
} Pattern;


/* number of siblings for each tree */
/* extern const byte numsiblings[]; */

/* access to siblings */
#define sib1(t)         ((t) + 1)
#define sib2(t)         ((t) + (t)->u.ps)


#endif

