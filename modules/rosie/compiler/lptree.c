/*
** $Id: lptree.c,v 1.21 2015/09/28 17:01:25 roberto Exp $
** Portions Copyright 2013, Lua.org & PUC-Rio  (see 'lpeg.html' for license)
** Portions Copyright 2016, 2017, 2018, Jamie A. Jennings  (MIT license, like lpeg)
*/

#if defined(__linux__)
#define _GNU_SOURCE		/* for asprintf */
#endif

#include <stdlib.h>
#include <alloca.h>
#include <ctype.h>
#include <limits.h>
#include <string.h>

#include <time.h>

#include "lua.h"
#include "lauxlib.h"

#include "lptypes.h"
#include "lpcap.h"
#include "lpcode.h"
#include "lpprint.h"
#include "file.h"
#include "lptree.h"

/* ------------------------------------------------------------------
 * FUTURE: The definition of rstr is duplicated from librosie.h. Need
 * to rework the header files such that this definition is available
 * to any file that includes librosie.h, plus this one, lptree.c
 */
#define byte_ptr unsigned char *

typedef struct rosie_string {
     uint32_t len;
     byte_ptr ptr;
} rstr;

typedef struct rosie_string str;
/* ------------------------------------------------------------------ */

#include "rbuf.h"
#include "rpeg.h"
#include "ktable.h" 
#include "ktable-macros.h"
#include "json.h"

#if !defined(DEBUG)
#define DEBUG 0
#endif


/* --------------------------------------------------------------------------------------------------- */
/* TEMPORARY */
static const char *strerror_error(const char *filename, int line, int code) {
  char *error_message;
  if (!asprintf(&error_message, "%s:%d: INVALID ERROR CODE %d", filename, line, code))
    return "ERROR: asprintf failed";
  return error_message;
}

#define MESSAGES_LEN(array) ((int) ((sizeof (array) / sizeof (const char *))))

#define STRERROR(code, message_list)					\
  ( (((code) > 0) && ((code) < MESSAGES_LEN(message_list)))		\
    ? (message_list)[(code)]						\
    : strerror_error(__FILE__, __LINE__, code) )
/* --------------------------------------------------------------------------------------------------- */


static TTree *newgrammar (lua_State *L, int arg);


/*
** returns a reasonable name for value at index 'idx' on the stack
*/
static const char *val2str (lua_State *L, int idx) {
  const char *k = lua_tostring(L, idx);
  if (k != NULL)
    return lua_pushfstring(L, "%s", k);
  else
    return lua_pushfstring(L, "(a %s)", luaL_typename(L, idx));
}


/*
** Fix a TOpenCall into a TCall node, using table 'postable' to
** translate a key to its rule address in the tree. Raises an
** error if key does not exist.
*/
static void fixonecall (lua_State *L, int postable, TTree *g, TTree *t, Ktable *kt) {
  int n;
  size_t len;
  const char *rulename = ktable_element_name(kt, t->key, &len);
  lua_pushlstring(L, rulename, len);

  lua_gettable(L, postable);  /* query name in position table */
  n = lua_tonumber(L, -1);  /* get (absolute) position */
  lua_pop(L, 1);  /* remove position */
  if (n == 0) {  /* no position? */
    luaL_error(L, "rule '%s' undefined in given grammar", rulename);
  }
  t->tag = TCall;
  t->u.ps = n - (t - g);  /* position relative to node */
  assert(sib2(t)->tag == TRule);
  sib2(t)->key = t->key;
}


/*
** Transform left associative constructions into right
** associative ones, for sequence and choice; that is:
** (t11 + t12) + t2  =>  t11 + (t12 + t2)
** (t11 * t12) * t2  =>  t11 * (t12 * t2)
** (that is, Op (Op t11 t12) t2 => Op t11 (Op t12 t2))
*/
static void correctassociativity (TTree *tree) {
  TTree *t1 = sib1(tree);
  assert(tree->tag == TChoice || tree->tag == TSeq);
  while (t1->tag == tree->tag) {
    int n1size = tree->u.ps - 1;  /* t1 == Op t11 t12 */
    int n11size = t1->u.ps - 1;
    int n12size = n1size - n11size - 1;
    memmove(sib1(tree), sib1(t1), n11size * sizeof(TTree)); /* move t11 */
    tree->u.ps = n11size + 1;
    sib2(tree)->tag = tree->tag;
    sib2(tree)->u.ps = n12size + 1;
  }
}

#if 0
/* find a duplicate for the ktable element at 'key' */
static int find_ktable_duplicate(Ktable *kt, int key) {
  size_t name_len, target_len;
  const char *name;
  const char *target_element = ktable_element_name(kt, key, &target_len);
  int last = ktable_len(kt);
  for (int i = 1; i <= last; i++) {
    name = ktable_element_name(kt, i, &name_len);
    if ((i != key) &&
	(ktable_name_cmp(name, name_len, target_element, target_len)))
      return i;
  }
  return 0;			/* no match */
}
#endif

/*
** Make final adjustments in a tree. Fix open calls in tree 't',
** making them refer to their respective rules or raising appropriate
** errors (if not inside a grammar). Correct associativity of associative
** constructions (making them right associative). 
*/
static void finalfix (lua_State *L, int postable, TTree *g, TTree *t, Ktable *kt) {
 tailcall:
  switch (t->tag) {
    case TGrammar:  /* subgrammars were already fixed */
      return;
    case TBackref:
      return;
    case TOpenCall: {
      if (g != NULL)  /* inside a grammar? */
        fixonecall(L, postable, g, t, kt);
      else {  /* open call outside grammar */
        luaL_error(L, "rule '%s' used outside a grammar", ktable_element(kt, t->key));
      }
      break;
    }
    case TSeq: case TChoice:
      correctassociativity(t);
      break;
    case TNoTree:
      luaL_error(L, "cannot compile expression containing a precompiled pattern");
      break;
  }
  switch (numsiblings[t->tag]) {
    case 1: /* finalfix(L, postable, g, sib1(t)); */
      t = sib1(t); goto tailcall;
    case 2:
      finalfix(L, postable, g, sib1(t), kt);
      t = sib2(t); goto tailcall;  /* finalfix(L, postable, g, sib2(t)); */
    default: assert(numsiblings[t->tag] == 0); break;
  }
}


/* ---------------------------------------------------------------------------------------- */

static Pattern *getpattern (lua_State *L, int idx) {
  Pattern *p = (Pattern *)luaL_checkudata(L, idx, PATTERN_T);
  assert(p->kt);
  return p;
}


static int getsize (lua_State *L, int idx) {
  return (lua_rawlen(L, idx) - sizeof(Pattern)) / sizeof(TTree) + 1;
}


static TTree *gettree (lua_State *L, int idx, int *len) {
  Pattern *p = getpattern(L, idx);
  if (len)
    *len = getsize(L, idx);
  return p->tree;
}



/*
** {===================================================================
** KTable manipulation
**
** - The ktable of a pattern 'p' can be shared by other patterns that
** contain 'p' and no other constants. Because of this sharing, we
** should not add elements to a 'ktable' unless it was freshly created
** for the new pattern.
**
** - The maximum index in a ktable is USHRT_MAX, because trees and
** patterns use unsigned shorts to store those indices.
**   --> Rosie change: maximum index is MAX_CAPLISTSIZE
** ====================================================================
*/

/*
** Create a new 'ktable' to the pattern at the top of the stack.
*/
static void newktable (lua_State *L, int n) {
  pushnewktable(L, n);  /* create a fresh table */
  setktable(L, -2);  /* set it as 'ktable' for pattern */
}


/*
** Add element 'idx' to 'ktable' of pattern at the top of the stack;
** Return index of new element.
** If new element is nil, does not add it to table (as it would be
** useless) and returns 0, as ktable[0] is always nil.
*/
static int addtoktable (lua_State *L, int idx) {
  if (lua_isnil(L, idx))  /* nil value? */
    return 0;
  else
    if (lua_isstring(L, idx)) {
      LOGf("adding '%s'\n", lua_tostring(L, idx));
    }
  int n;  
  getktable(L, -1);  /* get ktable from pattern */  
  Ktable *kt = lua_touserdata(L, -1); 
  lua_pop(L, 1);			    /* remove ktable */
  n = ktable_len(kt); 
  assert( n >= 0 && n <= KTABLE_INDEX_T_MAX );
  if (n >= KTABLE_INDEX_T_MAX) 
    return luaL_error(L, "(add) too many captures in pattern: %d", n); 
  else if (!lua_isstring(L, idx)) 
    return luaL_error(L, "(add) ktable entry is not a string: %s", lua_tostring(L, idx)); 
  else { 
    size_t len;
    const char *s = lua_tolstring(L, idx, &len); /* element to be added */ 
    assert (s);
    if (!ktable_add(kt, (const char *)s, len))
      luaL_error(L, "(add) out of memory");
    return n+1;			/* index of newly added item */
  } 
} 

/*
** Concatentate the contents of table 'idx1' into table 'idx2'.
** (Assume that both indices are negative.)
** Return the original length of table 'idx2' (or 0, if no
** element was added, as there is no need to correct any index).
*/
static int concattable (lua_State *L, int idx1, int idx2) {
  if (!isktable(L, idx1) || !isktable(L, idx2))
    luaL_error(L, "in concattable, did not find ktables");
  assert( (idx1 < 0) && (idx2 < 0) );
  Ktable *kt1 = lua_touserdata(L, idx1); 
  Ktable *kt2 = lua_touserdata(L, idx2); 
  assert( kt1 != kt2 );
  int n = 0;
  int err = ktable_concat(kt1, kt2, &n);
  if (err) {
    const char *msg = KTABLE_MESSAGES[err];
    luaL_error(L, msg);
  }
  return n;
}

/*
** When joining 'ktables', constants from one of the subpatterns must
** be renumbered; 'correctkeys' corrects their indices (adding 'n'
** to each of them)
*/
static void correctkeys (TTree *tree, int n) {
  if (n == 0) return;  /* no correction */
 tailcall:
  assert(tree != NULL);
  switch (tree->tag) {
  case TOpenCall: case TCall: case TRunTime: case TRule: case TBackref: {
    if (tree->key > 0)
      tree->key += n;
    break;
  }
  case TCapture: {
    if (tree->key > 0)
      tree->key += n;
    break;
  }
  default: break;
  }
  switch (numsiblings[tree->tag]) {
  case 1:  /* correctkeys(sib1(tree), n); */
    tree = sib1(tree); goto tailcall;
  case 2:
    correctkeys(sib1(tree), n);
    tree = sib2(tree); goto tailcall;  /* correctkeys(sib2(tree), n); */
  default: assert(numsiblings[tree->tag] == 0); break;
  }
}

/*
** Join the ktables from p1 and p2, copying their contents into a new
** ktable for the new pattern at the top of the stack.
**
** Rosie modification from lpeg: no more sharing of ktables!
*/
static void joinktables (lua_State *L, int p1, TTree *t2, int p2) {
  int n1, n2;

  assert( (p1 > 0) && (p2 > 0) );

  getktable(L, p1);
  getktable(L, p2);

  assert( lua_touserdata(L, -1) != NULL ); 
  assert( lua_touserdata(L, -2) != NULL ); 

  Ktable *k2 = lua_touserdata(L, -1);
  Ktable *k1 = lua_touserdata(L, -2);
  n1 = ktable_len(k1);
  n2 = ktable_len(k2);

  pushnewktable(L, n1 + n2);  /* create ktable for new pattern */
  /* stack: new p; ktable p1; ktable p2; new ktable */
  int n = concattable(L, -3, -1);  /* from p1 into new ktable */
  UNUSED(n);
  assert( n >= 0 );
  if (k1 != k2) {
    n = concattable(L, -2, -1);  /* from p2 into new ktable */
    assert( n >= 0 );
  }

  Ktable *newkt = lua_touserdata(L, -1); UNUSED(newkt);
  assert( ktable_len(newkt) == ((k1 == k2) ? n1 : (n1 + n2)) );

  setktable(L, -4);  /* new ktable becomes 'p' environment */
  lua_pop(L, 2);  /* pop other ktables */
  if (k1 != k2) {
    correctkeys(t2, n1);  /* correction for indices from p2 */
  }
}

/*
** copy 'ktable' of element 'idx' to new tree (on top of stack)
*/
static void copyktable (lua_State *L, int idx) {
  assert( idx > 0 );
  /* stack: pat */
  getktable(L, idx);
  pushnewktable(L, ktable_len((Ktable *)lua_touserdata(L, -1)));
  concattable(L, -2, -1);
  /* stack: newkt, kt, pat */
  setktable(L, -3);
  lua_pop(L, 1);
}


/*
** merge 'ktable' from 'stree' at stack index 'idx' into 'ktable'
** from tree at the top of the stack, and correct corresponding
** tree.
*/
static void mergektable (lua_State *L, int idx, TTree *stree) {
  int n;
  assert( idx > 0 );
  getktable(L, -1);
  getktable(L, idx);
  assert( lua_islightuserdata(L, -1) && lua_islightuserdata(L, -2) );
  assert( lua_touserdata(L, -1) != lua_touserdata(L, -2) );
  n = concattable(L, -1, -2);
  if (n < 0) {
    LOGf("concattable result is error code %d\n", n);
    const char *msg = KTABLE_MESSAGES[-n];
    luaL_error(L, msg);
  }
  lua_pop(L, 2);  /* remove both ktables */
  correctkeys(stree, n);
}


/*
** Create a new 'ktable' to the pattern at the top of the stack, adding
** all elements from pattern 'p' (if not 0) plus element 'idx' to it.
** Return index of new element.
*/
static int addtonewktable (lua_State *L, int p, int idx) {
  newktable(L, 1);
  if (p)
    mergektable(L, p, NULL);
  return addtoktable(L, idx);
}

/* }====================================================== */


/*
** {======================================================
** Tree generation
** =======================================================
*/

/*
** In 5.2, could use 'luaL_testudata'...
*/
static int testpattern (lua_State *L, int idx) {
  if (lua_touserdata(L, idx)) {  /* value is a userdata? */
    if (lua_getmetatable(L, idx)) {  /* does it have a metatable? */
      luaL_getmetatable(L, PATTERN_T);
      if (lua_rawequal(L, -1, -2)) {  /* does it have the correct mt? */
        lua_pop(L, 2);  /* remove both metatables */
        return 1;
      }
    }
  }
  return 0;
}


/*
** Create a pattern. Set its uservalue equal to its metatable. (It
** could be any empty sequence; the metatable is at hand here, so we
** use it.)  Rosie change: the uservalue was also the ktable.  Now,
** the ktable is a pure C (non-lua) data structure that is part of the
** Pattern struct.
*/
static TTree *newtree (lua_State *L, int len) {
  size_t size = (len - 1) * sizeof(TTree) + sizeof(Pattern);
  Pattern *p = (Pattern *)lua_newuserdata(L, size); /* stack: pattern */
  luaL_getmetatable(L, PATTERN_T);		    /* stack: mt, pattern */
  lua_pushvalue(L, -1);				    /* stack: mt, mt, pattern */
  lua_setuservalue(L, -3);			    /* stack: mt, pattern */
  lua_setmetatable(L, -2);			    /* stack: pattern */
  p->code = NULL;  p->codesize = 0;
  p->kt = ktable_new(0, 0);
  return p->tree;
}


static TTree *newleaf (lua_State *L, int tag) {
  TTree *tree = newtree(L, 1);
  tree->tag = tag;
  return tree;
}


static TTree *newcharset (lua_State *L) {
  TTree *tree = newtree(L, bytes2slots(CHARSETSIZE) + 1);
  tree->tag = TSet;
  loopset(i, treebuffer(tree)[i] = 0);
  return tree;
}


/*
** add to tree a sequence where first sibling is 'sib' (with size
** 'sibsize'); returns position for second sibling
*/
static TTree *seqaux (TTree *tree, TTree *sib, int sibsize) {
  tree->tag = TSeq; tree->u.ps = sibsize + 1;
  memcpy(sib1(tree), sib, sibsize * sizeof(TTree));
  return sib2(tree);
}


/*
** Build a sequence of 'n' nodes, each with tag 'tag' and 'u.n' got
** from the array 's' (or 0 if array is NULL). (TSeq is binary, so it
** must build a sequence of sequence of sequence...)
*/
static void fillseq (TTree *tree, int tag, int n, const char *s) {
  int i;
  for (i = 0; i < n - 1; i++) {  /* initial n-1 copies of Seq tag; Seq ... */
    tree->tag = TSeq; tree->u.ps = 2;
    sib1(tree)->tag = tag;
    sib1(tree)->u.n = s ? (byte)s[i] : 0;
    tree = sib2(tree);
  }
  tree->tag = tag;  /* last one does not need TSeq */
  tree->u.n = s ? (byte)s[i] : 0;
}


/*
** Numbers as patterns:
** 0 == true (always match); n == TAny repeated 'n' times;
** -n == not (TAny repeated 'n' times)
*/
static TTree *numtree (lua_State *L, int n) {
  if (n == 0)
    return newleaf(L, TTrue);
  else {
    TTree *tree, *nd;
    if (n > 0)
      tree = nd = newtree(L, 2 * n - 1);
    else {  /* negative: code it as !(-n) */
      n = -n;
      tree = newtree(L, 2 * n);
      tree->tag = TNot;
      nd = sib1(tree);
    }
    fillseq(nd, TAny, n, NULL);  /* sequence of 'n' any's */
    return tree;
  }
}


/*
** Convert value at index 'idx' to a pattern
*/
static TTree *getpatt (lua_State *L, int idx, int *len) {
  TTree *tree;
  switch (lua_type(L, idx)) {
    case LUA_TSTRING: {
      size_t slen;
      const char *s = lua_tolstring(L, idx, &slen);  /* get string */
      if (slen == 0)  /* empty? */
        tree = newleaf(L, TTrue);  /* always match */
      else {
        tree = newtree(L, 2 * (slen - 1) + 1);
        fillseq(tree, TChar, slen, s);  /* sequence of 'slen' chars */
      }
      break;
    }
    case LUA_TNUMBER: {
      int n = lua_tointeger(L, idx);
      tree = numtree(L, n);
      break;
    }
    case LUA_TBOOLEAN: {
      tree = (lua_toboolean(L, idx) ? newleaf(L, TTrue) : newleaf(L, TFalse));
      break;
    }
    case LUA_TTABLE: {
      tree = newgrammar(L, idx);
      break;
    }
    default: {
      return gettree(L, idx, len);
    }
  }
  lua_replace(L, idx);  /* put new tree into 'idx' slot */
  if (len)
    *len = getsize(L, idx);
  return tree;
}


/*
** create a new tree, whith a new root and one sibling.
** Sibling must be on the Lua stack, at index 1.
*/
static TTree *newroot1sib (lua_State *L, int tag) {
  int s1;
  TTree *tree1 = getpatt(L, 1, &s1);
  TTree *tree = newtree(L, 1 + s1);  /* stack: new tree */
  tree->tag = tag;
  memcpy(sib1(tree), tree1, s1 * sizeof(TTree));
  copyktable(L, 1);
  return tree;
}


/*
** create a new tree, whith a new root and 2 siblings.
** Siblings must be on the Lua stack, first one at index 1.
*/
static TTree *newroot2sib (lua_State *L, int tag) {
  int s1, s2;
  TTree *tree1 = getpatt(L, 1, &s1);
  TTree *tree2 = getpatt(L, 2, &s2);
  getktable(L, 1);
  getktable(L, 2);
  Ktable *kt1 = lua_touserdata(L, -1); UNUSED(kt1);
  Ktable *kt2 = lua_touserdata(L, -2); UNUSED(kt2);
  lua_pop(L, 2);
  assert( kt1 != NULL );
  assert( kt2 != NULL );
  TTree *tree = newtree(L, 1 + s1 + s2);  /* create new tree */
  tree->tag = tag;
  tree->u.ps =  1 + s1;
  memcpy(sib1(tree), tree1, s1 * sizeof(TTree));
  memcpy(sib2(tree), tree2, s2 * sizeof(TTree));
  joinktables(L, 1, sib2(tree), 2);
  return tree;
}


static int lp_P (lua_State *L) {
  luaL_checkany(L, 1);
  getpatt(L, 1, NULL);
  lua_settop(L, 1);
  return 1;
}

/* rosie */
static int lp_halt (lua_State *L) {
  newleaf(L, THalt);
  return 1;
}


/*
** sequence operator; optimizations:
** false x => false, x true => x, true x => x
** (cannot do x . false => false because x may have runtime captures)
*/
static int lp_seq (lua_State *L) {
  TTree *tree1 = getpatt(L, 1, NULL);
  TTree *tree2 = getpatt(L, 2, NULL);
  if (tree1->tag == TFalse || tree2->tag == TTrue)
    lua_pushvalue(L, 1);  /* false . x == false, x . true = x */
  else if (tree1->tag == TTrue)
    lua_pushvalue(L, 2);  /* true . x = x */
  else
    newroot2sib(L, TSeq);
  return 1;
}


/*
** choice operator; optimizations:
** charset / charset => charset
** true / x => true, x / false => x, false / x => x
** (x / true is not equivalent to true)
*/
/* for rosie's THalt, we could in future do this optimization: THalt / x => THalt */
static int lp_choice (lua_State *L) {
  Charset st1, st2;
  TTree *t1 = getpatt(L, 1, NULL);
  TTree *t2 = getpatt(L, 2, NULL);
  if (tocharset(t1, &st1) && tocharset(t2, &st2)) {
    TTree *t = newcharset(L);
    loopset(i, treebuffer(t)[i] = st1.cs[i] | st2.cs[i]);
  }
  else if (nofail(t1) || t2->tag == TFalse)
    lua_pushvalue(L, 1);  /* true / x => true, x / false => x */
  else if (t1->tag == TFalse)
    lua_pushvalue(L, 2);  /* false / x => x */
  else
    newroot2sib(L, TChoice);
  return 1;
}


/*
** p^n
*/
static int lp_star (lua_State *L) {
  int size1;
  int n = (int)luaL_checkinteger(L, 2);
  TTree *tree1 = getpatt(L, 1, &size1);
  if (n >= 0) {  /* seq tree1 (seq tree1 ... (seq tree1 (rep tree1))) */
    TTree *tree = newtree(L, (n + 1) * (size1 + 1));
    if (nullable(tree1))
      luaL_error(L, "loop body may accept empty string");
    while (n--)  /* repeat 'n' times */
      tree = seqaux(tree, tree1, size1);
    tree->tag = TRep;
    memcpy(sib1(tree), tree1, size1 * sizeof(TTree));
  }
  else {  /* choice (seq tree1 ... choice tree1 true ...) true */
    TTree *tree;
    n = -n;
    /* size = (choice + seq + tree1 + true) * n, but the last has no seq */
    tree = newtree(L, n * (size1 + 3) - 1);
    for (; n > 1; n--) {  /* repeat (n - 1) times */
      tree->tag = TChoice; tree->u.ps = n * (size1 + 3) - 2;
      sib2(tree)->tag = TTrue;
      tree = sib1(tree);
      tree = seqaux(tree, tree1, size1);
    }
    tree->tag = TChoice; tree->u.ps = size1 + 1;
    sib2(tree)->tag = TTrue;
    memcpy(sib1(tree), tree1, size1 * sizeof(TTree));
  }
  copyktable(L, 1);
  return 1;
}


/*
** #p == &p
*/
static int lp_and (lua_State *L) {
  newroot1sib(L, TAnd);
  return 1;
}


/*
** -p == !p
*/
static int lp_not (lua_State *L) {
  newroot1sib(L, TNot);
  return 1;
}


/*
** [t1 - t2] == Seq (Not t2) t1
** If t1 and t2 are charsets, make their difference.
*/
static int lp_sub (lua_State *L) {
  Charset st1, st2;
  int s1, s2;
  TTree *t1 = getpatt(L, 1, &s1);
  TTree *t2 = getpatt(L, 2, &s2);
  if (tocharset(t1, &st1) && tocharset(t2, &st2)) {
    TTree *t = newcharset(L);
    loopset(i, treebuffer(t)[i] = st1.cs[i] & ~st2.cs[i]);
  }
  else {
    TTree *tree = newtree(L, 2 + s1 + s2);
    tree->tag = TSeq;  /* sequence of... */
    tree->u.ps =  2 + s2;
    sib1(tree)->tag = TNot;  /* ...not... */
    memcpy(sib1(sib1(tree)), t2, s2 * sizeof(TTree));  /* ...t2 */
    memcpy(sib2(tree), t1, s1 * sizeof(TTree));  /* ... and t1 */
    joinktables(L, 1, sib1(tree), 2);
  }
  return 1;
}


static int lp_set (lua_State *L) {
  size_t l;
  const char *s = luaL_checklstring(L, 1, &l);
  TTree *tree = newcharset(L);
  while (l--) {
    setchar(treebuffer(tree), (byte)(*s));
    s++;
  }
  return 1;
}


static int lp_range (lua_State *L) {
  int arg;
  int top = lua_gettop(L);
  TTree *tree = newcharset(L);
  for (arg = 1; arg <= top; arg++) {
    int c;
    size_t l;
    const char *r = luaL_checklstring(L, arg, &l);
    luaL_argcheck(L, l == 2, arg, "range must have two characters");
    for (c = (byte)r[0]; c <= (byte)r[1]; c++)
      setchar(treebuffer(tree), c);
  }
  return 1;
}


/*
** Look-behind predicate
*/
static int lp_behind (lua_State *L) {
  TTree *tree;
  TTree *tree1 = getpatt(L, 1, NULL);
  int n = fixedlen(tree1);
  luaL_argcheck(L, n >= 0, 1, "pattern may not have fixed length");
  luaL_argcheck(L, !hascaptures(tree1), 1, "pattern have captures");
  luaL_argcheck(L, n <= MAXBEHIND, 1, "pattern too long to look behind");
  tree = newroot1sib(L, TBehind);
  tree->u.n = n;
  return 1;
}

/*
** Create a non-terminal
*/
static int lp_V (lua_State *L) {
  TTree *tree = newleaf(L, TOpenCall);
  luaL_argcheck(L, !lua_isnoneornil(L, 1), 1, "non-nil value expected");
  tree->key = addtonewktable(L, 0, 1);
  LOGf("just after call to addtonewktable, tree->key is %d\n", tree->key);
  return 1;
}


/*
** Create a tree for a non-empty capture, with a body and
** optionally with an associated Lua value (at index 'labelidx' in the
** stack)
*/
static int capture_aux (lua_State *L, int cap, int labelidx) {
  TTree *tree = newroot1sib(L, TCapture);
  tree->cap = cap;
  tree->key = (labelidx == 0) ? 0 : addtonewktable(L, 1, labelidx);
  LOGf("just after call to addtonewktable, tree->key is %d\n", tree->key);
  return 1;
}


/*
** Fill a tree with an empty capture, using an empty (TTrue) sibling.
*/
static TTree *auxemptycap (TTree *tree, int cap) {
  tree->tag = TCapture;
  tree->cap = cap;
  sib1(tree)->tag = TTrue;
  return tree;
}


/*
** Create a tree for an empty capture
*/
/* static TTree *newemptycap (lua_State *L, int cap) { */
/*   return auxemptycap(newtree(L, 2), cap); */
/* } */


/*
** Create a tree for an empty capture with an associated Lua value
*/
static TTree *newemptycapkey (lua_State *L, int cap, int idx) {
  TTree *tree = auxemptycap(newtree(L, 2), cap);
  tree->key = addtonewktable(L, 0, idx);
  LOG("just after call to addtonewktable\n");
  return tree;
}

static TTree *newemptycapkey2 (lua_State *L, int cap, int idx, int idx2) {
  TTree *tree = newemptycapkey(L, cap, idx);
  /* second entry in ktable: constant capture data value */
  tree->u.n = addtoktable(L, idx2); 
  return tree;
}

/* static int lp_simplecapture (lua_State *L) { */
/*   return capture_aux(L, Csimple, 0); */
/* } */


/* static int lp_poscapture (lua_State *L) { */
/*   newemptycap(L, Cposition); */
/*   return 1; */
/* } */


static Instruction *prepcompile (lua_State *L, Pattern *p);


/* do the code generation for pattern (if needed), and return the
 * resulting number of instructions
 */
static int r_codegen_if_needed (lua_State *L) {
  Pattern *p = getpattern(L, 1);
  if (p->code == NULL)  /* not compiled yet? */
    if (!prepcompile(L, p)) lua_pushinteger(L, p->codesize);
    else lua_pushnil(L);
  else lua_pushinteger(L, p->codesize);
  return 1;
}

static int r_pattern_size (lua_State *L) {
  Pattern *p = getpattern(L, 1);
  size_t without_code = lua_rawlen(L, 1);
  size_t codesize = p->codesize * sizeof(Instruction);
  lua_pushinteger(L, without_code + codesize);
  return 1;
}

static int r_userdata_size (lua_State *L) {
  luaL_checktype(L, 1, LUA_TUSERDATA);
  lua_pushinteger(L, lua_rawlen(L, 1));
  return 1;
}

/* rosie capture */
static int r_capture (lua_State *L) {
  size_t len;
  luaL_checklstring(L, 2, &len); /* match name */
  if (len == 0)
    luaL_error(L, "capture name cannot be the empty string");
  else {
    if (len > KTABLE_MAX_ELEMENT_LEN) luaL_error(L, "capture name too long");
  }
  int result = capture_aux(L, Crosiecap, 2);
  return result;
}

/* rosie constant capture */
static int r_constcapture (lua_State *L) { 
  size_t len;
  luaL_checklstring(L, 1, &len); /* value (a constant string) */
  if (len > SHRT_MAX) luaL_error(L, "constant capture string too long");
  luaL_checklstring(L, 2, &len); /* rosie type (also called "match name") */
  if (len > SHRT_MAX) luaL_error(L, "capture name too long");
  /* first entry in ktable: pattern type  */
  newemptycapkey2(L, Crosieconst, 2, 1); /* pushes a TTree onto the stack */
  return 1;
}  
  
/* rosie backreference (different from lpeg backreference). */
/* first arg is pattern (used at compile time), second is pattern name (used at runtime) */
static int r_backref (lua_State *L) {
  size_t len;
  getpattern(L, 1);
  luaL_checklstring(L, 2, &len); /* pattern (capture) name */
  if (len == 0) luaL_error(L, "capture name cannot be the empty string");
  else {
    if (len > KTABLE_MAX_ELEMENT_LEN) luaL_error(L, "capture name too long");
  }
  TTree *tree;
  tree = newroot1sib(L, TBackref); /* uses pattern at index 1 on lua stack */
  tree->key = addtonewktable(L, 0, 2);
  return 1;
}


/* }====================================================== */


/*
** {======================================================
** Grammar - Tree generation
** =======================================================
*/

/*
** push on the stack the index and the pattern for the
** initial rule of grammar at index 'arg' in the stack;
** also add that index into position table.
*/
static void getfirstrule (lua_State *L, int arg, int postab) {
  LOGf("*** getfirstrule(grammar table at stack position %d, postable at %d)\n", arg, postab);
  int top;
  (void)(top);			/* suppress 'top is unused' warning when not debugging */
  if (DEBUG) { top = lua_gettop(L); }
  lua_rawgeti(L, arg, 1);  /* access first element */
  if (lua_isstring(L, -1)) {  /* is it the name of initial rule? */
    lua_pushvalue(L, -1);  /* duplicate it to use as key */
    lua_gettable(L, arg);  /* get associated rule */
  }
  else {
    lua_pushinteger(L, 1);  /* key for initial rule */
    lua_insert(L, -2);  /* put it before rule */
  }
  if (!testpattern(L, -1)) {  /* initial rule not a pattern? */
    if (lua_isnil(L, -1))
      luaL_error(L, "grammar has no initial rule");
    else
      luaL_error(L, "initial rule '%s' is not a pattern", lua_tostring(L, -2));
  }
  lua_pushvalue(L, -2);  /* push key */
  lua_pushinteger(L, 1);  /* push rule position (after TGrammar) */
  lua_settable(L, postab);  /* insert pair at position table */
  if (DEBUG) assert( (lua_gettop(L) - top) == 2 );
}

/*
** traverse grammar at index 'arg', pushing all its keys and patterns
** into the stack. Create a new table (before all pairs key-pattern) to
** collect all keys and their associated positions in the final tree
** (the "position table").
** Return the number of rules and (in 'totalsize') the total size
** for the new tree.
*/
static int collectrules (lua_State *L, int arg, int *totalsize) {
  LOGf("*** collectrules(grammar table at stack position %d, -)\n", arg);
  int n = 1;  /* to count number of rules */
  int postab = lua_gettop(L) + 1;  /* index of position table */
  int size;  /* accumulator for total size */
  lua_newtable(L);  /* create position table */
  getfirstrule(L, arg, postab);
  /* stack: first rule pattern, first rule index, postable, ... */
  size = 2 + getsize(L, postab + 2);  /* TGrammar + TRule + rule */
  lua_pushnil(L);  /* prepare to traverse grammar table */
  while (lua_next(L, arg) != 0) {
    if (lua_tonumber(L, -2) == 1 ||
        lp_equal(L, -2, postab + 1)) {  /* initial rule? */
      lua_pop(L, 1);  /* remove value (keep key for lua_next) */
      continue;
    }
    if (!testpattern(L, -1))  /* value is not a pattern? */
      luaL_error(L, "rule '%s' is not a pattern", val2str(L, -2));
    luaL_checkstack(L, LUA_MINSTACK, "grammar has too many rules");
    lua_pushvalue(L, -2);  /* push key (to insert into position table) */
    lua_pushinteger(L, size);
    lua_settable(L, postab);
    size += 1 + getsize(L, -1);  /* update size */
    lua_pushvalue(L, -2);  /* push key (for next lua_next) */
    n++;
  }
  *totalsize = size + 1;  /* TTrue to finish list of rules */
  return n;
}


static void buildgrammar (lua_State *L, TTree *grammar, int frule, int n) {
  int i;
  TTree *nd = sib1(grammar);  /* auxiliary pointer to traverse the tree */
  for (i = 0; i < n; i++) {  /* add each rule into new tree */
    int ridx = frule + 2*i + 1;  /* index of i-th rule */
    int rulesize;
    TTree *rn = gettree(L, ridx, &rulesize);
    nd->tag = TRule;
    nd->key = 0;
    nd->cap = i;		/* rule number */
    nd->u.ps = rulesize + 1;	/* point to next rule */
    memcpy(sib1(nd), rn, rulesize * sizeof(TTree));  /* copy rule */
    mergektable(L, ridx, sib1(nd));  /* merge its ktable into new one */
    nd = sib2(nd);  /* move to next rule */
  }
  nd->tag = TTrue;  /* finish list of rules */
}


/*
** Check whether a tree has potential infinite loops
*/
static int checkloops (TTree *tree) {
 tailcall:
  if (tree->tag == TRep && nullable(sib1(tree)))
    return 1;
  else if (tree->tag == TGrammar)
    return 0;  /* sub-grammars already checked */
  else {
    switch (numsiblings[tree->tag]) {
      case 1:  /* return checkloops(sib1(tree)); */
        tree = sib1(tree); goto tailcall;
      case 2:
        if (checkloops(sib1(tree))) return 1;
        /* else return checkloops(sib2(tree)); */
        tree = sib2(tree); goto tailcall;
      default: assert(numsiblings[tree->tag] == 0); return 0;
    }
  }
}


static int verifyerror (lua_State *L, int *passed, int npassed) {
  if (!isktable(L, -1)) luaL_error(L, "%s:did not find ktable at top of stack", __func__);
  int i, j;
  for (i = npassed - 1; i >= 0; i--) {  /* search for a repetition */
    for (j = i - 1; j >= 0; j--) {
      if (passed[i] == passed[j]) {
        ktable_get(L, -1, passed[i]);  /* get rule's key */
        return luaL_error(L, "rule '%s' may be left recursive", val2str(L, -1));
      }
    }
  }
  return luaL_error(L, "too many left calls in grammar");
}


/*
** Check whether a rule can be left recursive; raise an error in that
** case; otherwise return 1 iff pattern is nullable.
** The return value is used to check sequences, where the second pattern
** is only relevant if the first is nullable.
** Parameter 'nb' works as an accumulator, to allow tail calls in
** choices. ('nb' true makes function returns true.)
** Assume ktable at the top of the stack.
*/
static int verifyrule (lua_State *L, TTree *tree, int *passed, int npassed,
                       int nb) {
 tailcall:
  if (!isktable(L, -1)) luaL_error(L, "%s:did not find ktable at top of stack", __func__);
  switch (tree->tag) {
    case TChar: case TSet: case TAny:
    case TFalse: case THalt:	/* rosie adds THalt */
      return nb;  /* cannot pass from here */
    case TTrue:
    case TBehind:  /* look-behind cannot have calls */
      return 1;
    case TNot: case TAnd: case TRep:
      /* return verifyrule(L, sib1(tree), passed, npassed, 1); */
      tree = sib1(tree); nb = 1; goto tailcall;
    case TCapture: case TRunTime:
      /* return verifyrule(L, sib1(tree), passed, npassed, nb); */
      tree = sib1(tree); goto tailcall;
    case TCall:
      /* return verifyrule(L, sib2(tree), passed, npassed, nb); */
      tree = sib2(tree); goto tailcall;
    case TSeq:  /* only check 2nd child if first is nb */
      if (!verifyrule(L, sib1(tree), passed, npassed, 0))
        return nb;
      /* else return verifyrule(L, sib2(tree), passed, npassed, nb); */
      tree = sib2(tree); goto tailcall;
    case TChoice:  /* must check both children */
      nb = verifyrule(L, sib1(tree), passed, npassed, nb);
      /* return verifyrule(L, sib2(tree), passed, npassed, nb); */
      tree = sib2(tree); goto tailcall;
    case TRule:
      if (npassed >= MAXRULES)
        return verifyerror(L, passed, npassed);
      else {
        passed[npassed++] = tree->key;
        /* return verifyrule(L, sib1(tree), passed, npassed); */
        tree = sib1(tree); goto tailcall;
      }
    case TGrammar:
      return nullable(tree);  /* sub-grammar cannot be left recursive */
    default: assert(0); return 0;
  }
}


static void verifygrammar (lua_State *L, TTree *grammar) {
  if (!isktable(L, -1)) luaL_error(L, "%s:did not find ktable at top of stack", __func__);
  int passed[MAXRULES];
  TTree *rule;
  /* check left-recursive rules */
  for (rule = sib1(grammar); rule->tag == TRule; rule = sib2(rule)) {
    if (rule->key == 0) continue;  /* unused rule */
    if (DEBUG) {
      ktable_get(L, -1, rule->key);
      assert( lua_isstring(L, -1) );
      lua_pop(L, 1);
    }
    verifyrule(L, sib1(rule), passed, 0, 0);
  }
  assert(rule->tag == TTrue);
  /* check infinite loops inside rules */
  for (rule = sib1(grammar); rule->tag == TRule; rule = sib2(rule)) {
    if (rule->key == 0) continue;  /* unused rule */
    if (checkloops(sib1(rule))) {
      ktable_get(L, -1, rule->key);
      luaL_error(L, "empty loop in rule '%s'", val2str(L, -1));
    }
  }
  assert(rule->tag == TTrue);
}


/*
** Give a name for the initial rule if it is not referenced.  Assumes
** ktable is on top of stack.
*/
static void initialrulename (lua_State *L, TTree *grammar, int frule) {
  /* FUTURE: streamline this */
  if (sib1(grammar)->key == 0) {  /* initial rule is not referenced? */
    Ktable *kt = lua_touserdata(L, -1);
    int n = ktable_len(kt) + 1;  /* index for name */
    LOGf("initial rule not referenced, and n = %d\n", n);
    lua_pushvalue(L, frule);  /* rule's name */
    assert( lua_isstring(L, -1) );
    size_t name_len;
    const char *name = lua_tolstring(L, -1, &name_len); 
    int actualpos = ktable_add(kt, name, name_len);
    if (!actualpos)
      luaL_error(L, "(initial rule) out of memory");
    lua_pop(L, 1);		/* remove rule name (string) */
    assert( actualpos == n );
    sib1(grammar)->key = n;
  }
}


static TTree *newgrammar (lua_State *L, int arg) {
  int treesize;
  int frule = lua_gettop(L) + 2;  /* position of first rule's key */
  int n = collectrules(L, arg, &treesize);
  /* stack: first rule pattern, first rule index/key, postable */
  TTree *g = newtree(L, treesize);
  luaL_argcheck(L, n <= MAXRULES, arg, "grammar has too many rules");
  g->tag = TGrammar;  g->u.n = n;
  pushnewktable(L, n);  /* create 'ktable' on top of stack*/
  Ktable *kt = (Ktable *)lua_touserdata(L, -1);
  setktable(L, -2);
  buildgrammar(L, g, frule, n);
  finalfix(L, frule - 1, g, sib1(g), kt); /* postable is at position (frule - 1) */
  /* get 'ktable' for new tree, because initialrulename, verifygrammar may use it */
  getktable(L, -1);
  initialrulename(L, g, frule);
  verifygrammar(L, g);
  lua_pop(L, 1);  /* remove 'ktable' */
  lua_insert(L, -(n * 2 + 2));  /* move new table to proper position */
  lua_pop(L, n * 2 + 1);  /* remove position table + rule pairs */
  return g;  /* new table at the top of the stack */
}

/* }====================================================== */

#if defined(DEBUG)
#define CHECK_KEY(k) do {						\
    if (((k) < 0) || ((k) > keymax)) {					\
      printf("tree->key %d < 1 or exceeds max (%d)\n", (k), keymax); \
      fflush(stdout);							\
    }									\
  } while(0);
#else
#define CHECK_KEY(k)
#endif

static void update_capture_keys(TTree *tree, int *mapping, int keymax) {
  int i;
  switch (tree->tag) {
    case TCapture: {
      CHECK_KEY(tree->key);
      tree->key = mapping[tree->key];
      if (tree->cap == Crosieconst) {
	CHECK_KEY(tree->u.n);
	tree->u.n = mapping[tree->u.n];
	assert(sib1(tree)->tag == TTrue);
      } else {
	update_capture_keys(sib1(tree), mapping, keymax);
      }
      break;
    }
    case TBackref: {
      CHECK_KEY(tree->key);
      tree->key = mapping[tree->key];
      break;
    }
    case TRule: {
      /* FUTURE: The ktable entries for grammar rules are actually not
	 used, so they could be removed at some point.  However,
	 eventually we will enhance grammars to allow multiple entry
	 points, and so we should leave them in place until after that
	 has been implemented. */
      CHECK_KEY(tree->key);
      tree->key = mapping[tree->key];
      update_capture_keys(sib1(tree), mapping, keymax);
      break;  /* do not process next rule as a sibling (TGrammar will do this) */
    }
    case TGrammar: {
      TTree *rule = sib1(tree);
      /* tree->u.n is the number of rules */
      for (i = 0; i < tree->u.n; i++) {
        update_capture_keys(rule, mapping, keymax);
        rule = sib2(rule);
      }
      assert(rule->tag == TTrue);  /* sentinel */
      break;
    }
    case TNoTree: {
      //luaL_error(L, "cannot compile expression containing a precompiled pattern");
      break;
    }
    default: {
      int sibs = numsiblings[tree->tag];
      if (sibs >= 1) {
        update_capture_keys(sib1(tree), mapping, keymax);
        if (sibs >= 2)
          update_capture_keys(sib2(tree), mapping, keymax);
      }
      break;
    }
  }
}

static void compact_ktable(lua_State *L, Pattern *p) {
  int idx, newidx;
  Ktable *ckt = ktable_compact(p->kt);
  if (!ckt) luaL_error(L, "%s:%d: could not compact ktable\n", __FILE__, __LINE__);
  //  if (ckt == p->kt) return; /* no action was taken by ktable_compact */

#if 0
  /* DEBUGGING */
  printf("BEFORE COMPACTING:\n");
  ktable_dump(p->kt);
  printf("AFTER COMPACTING:\n");
  ktable_dump(ckt);
  printf("---\n");
#endif
  /* 
     Create mapping from old to new.  
     Note: alloca fails in an odd way, not returning NULL, when
     ktable_len is large, so using calloc instead.
   */
  int *mapping = (int *)calloc(ktable_len(p->kt)+1, sizeof(int));
  if (!mapping) luaL_error(L, "%s:%d: out of memory (while compacting ktable)\n", __FILE__, __LINE__);
  mapping[0] = 0;
  for (idx = 1; idx <= ktable_len(p->kt); idx++) { /* 0 is an unused index */
    size_t len;
    const char *name = ktable_element_name(p->kt, idx, &len);
    newidx = ktable_compact_search(ckt, name, len); 
    if (newidx == 0) {
      free(mapping);
      //printf("incomplete compacted ktable: missing '%.*s'\n", (int) len, name);
      luaL_error(L, "%s:%d: incomplete compacted ktable\n", __FILE__, __LINE__);
    }
    mapping[idx] = newidx;
  } 
  update_capture_keys(p->tree, mapping, idx);
  ktable_free(p->kt);
  p->kt = ckt;
  free(mapping);
}

static Instruction *prepcompile (lua_State *L, Pattern *p) {
  finalfix(L, 0, NULL, p->tree, p->kt);
  compact_ktable(L, p); /* Remove duplicates in ktable, fixing up tree as needed */ 
  Instruction *code = compile(L, p);
  if (!code)
    /* Other errors will be caught in finalfix() */
    //luaL_error(L, "internal error in rpeg compiler");
    luaL_error(L, "cannot compile expression containing a precompiled pattern");
  return code;
}


static int lp_printtree (lua_State *L) {
  TTree *tree = getpatt(L, 1, NULL);
  Pattern *p = (Pattern *)luaL_checkudata(L, 1, PATTERN_T);
  prepcompile(L, p);
  int c = lua_toboolean(L, 2); 
  if (c) printktable(p->kt); 
  printtree(tree, 0);
  return 0;
}


static int lp_printcode (lua_State *L) {
  Pattern *p = getpattern(L, 1);
  printktable(p->kt);
  if (p->code == NULL)  /* not compiled yet? */
    prepcompile(L, p);
  printpatt(p->code, p->codesize);
  return 0;
}

/* ----------------------------------------------------------------------------- */

static int lp_make_compiled_pattern (lua_State *L, int nsize, Instruction *code, Ktable *kt) {
  // size_t bytes = nsize * sizeof(Instruction);
  //fprintf(stderr, "lp_make_compiled_pattern: bytes in instruction vector is %zu\n", bytes); 
  //fprintf(stderr, "lp_make_compiled_pattern: number of instructions is %d\n", nsize); 

  Pattern *p = (Pattern *)lua_newuserdata(L, sizeof(TTree) + sizeof(Pattern));

  /* stack: pattern */
  p->code = code;
  p->codesize = nsize;
  p->tree->tag = TNoTree;
  p->kt = kt;

  luaL_getmetatable(L, PATTERN_T); /* stack: mt, pat */
  lua_setmetatable(L, -2);	   /* stack: pat */       

  return 1;
}


static int lp_loadRPLX (lua_State *L) {
  const char *filename;
  /* stack: filename */
  filename = lua_tostring(L, 1);
  Chunk chunk;
  int err = file_load(filename, &chunk);
  if (err) {
    if ((err > 0) && (err < FILE_ERR_SENTINEL))
      luaL_error(L, FILE_MESSAGES[err]);
    else
      luaL_error(L, "unknown error in file_load (please report this as a bug)");
  }
  return lp_make_compiled_pattern(L, chunk.codesize, chunk.code, chunk.ktable);
}

static int lp_saveRPLX (lua_State *L) {
  const char *filename;
  /* stack: filename, pattern */
  filename = lua_tostring(L, 2);

  Pattern *p = getpattern(L, 1);
  finalfix(L, 0, NULL, p->tree, p->kt);
  if (p->code == NULL)  /* not compiled yet? */
    prepcompile(L, p);

  Chunk chunk;
  chunk.code = p->code;
  chunk.codesize = p->codesize;
  chunk.ktable = p->kt;
  int err = file_save(filename, &chunk);
  if (err) {
    if ((err > 0) && (err < FILE_ERR_SENTINEL))
      luaL_error(L, FILE_MESSAGES[err]);
    else
      luaL_error(L, "unknown error in file_save (please report this as a bug)");
  }
  return 0;
}


/* ---------------------------------------------------------------------------------------- */

static int dummy[1];
static void *output_buffer_key = (void *)&dummy[0];

static RBuffer *getbuffer(lua_State *L) {
  RBuffer *rbuf;
  int t;
  /* IF we are reusing the buffer, AND there is one already, then */
  /* reset it for use */
  lua_pushlightuserdata(L, output_buffer_key);
  t = lua_gettable(L, LUA_REGISTRYINDEX);
  if (t == LUA_TUSERDATA) {
    r_lua_buffreset(L, -1);
    return lua_touserdata(L, -1);
  }
  /* else make a new one, and IF we are resuing the buffer, save it */
  /* fprintf(stderr, "Making a new output buffer\n"); fflush(NULL); */
  rbuf = r_newbuffer(L);
  lua_pushlightuserdata(L, output_buffer_key);
  lua_pushvalue(L, -2);		/* Push copy of output buffer */
  lua_settable(L, LUA_REGISTRYINDEX);
  /* Leave output buffer on top of stack, just like r_newbuffer does */
  return rbuf;
}

/* ---------------------------------------------------------------------------------------- */

/* FUTURE:
 *
 * Need two distinct do_match functions: one that takes values from
 * Lua stack and puts results there, and one that is totally
 * independent of Lua.
 *
 */

/* required args: peg, input
 * optional args: start position, encoding type, total time accumulator, lpeg time accumulator
 * encoding types: debug, byte array, json, input
 * RESTRICTION: only a limited set of capture types are supported
*/

static inline int do_r_match (lua_State *L, int from_lua) {
  Pattern *p;
  Chunk chunk;
  Buffer *input;
  int start, etype, free_input;
  
  /* FUTURE: remove call to getpatt, thereby allowing ONLY a compiled peg here */
  p = (getpatt(L, 1, NULL), getpattern(L, 1));

  chunk.code = (p->code != NULL) ? p->code : prepcompile(L, p);
  chunk.codesize = p->codesize;
  chunk.ktable = p->kt;
  chunk.filename = NULL;
    
  /* From lua code, accept Lua string or ROSIE_BUFFER for input */
  int input_type = lua_type(L, SUBJIDX);
  switch (input_type) {
  case LUA_TSTRING: { 
    size_t l;
    const char *s = luaL_checklstring(L, SUBJIDX, &l);
    input = buf_from_const(s, l);
    free_input = 1;		/* true */
    break;
  }
  case LUA_TUSERDATA: {
    RBuffer *rbuf = luaL_testudata(L, SUBJIDX, ROSIE_BUFFER);
    if (rbuf) {
      input = *rbuf;
      free_input = 0;		/* false */
      break;
    }
  } /* fallthrough */
  case LUA_TLIGHTUSERDATA: {
    if (!from_lua) {
      rstr *rs = lua_touserdata(L, SUBJIDX);
      if (rs) {
	input = buf_from_const((char *)rs->ptr, rs->len);
	free_input = 1;		/* true */
	break;
      }
    }
  } /* fallthrough */
  default: 
    return luaL_argerror(L, SUBJIDX, "not rosie buffer or lua string");
  }
      
  lua_Integer duration0, duration1;
  start = luaL_optinteger(L, SUBJIDX+1, 1);
  etype = luaL_optinteger(L, SUBJIDX+2, ENCODE_BYTE);
  duration0 = luaL_optinteger(L, SUBJIDX+3, 0);	/* total time accumulator */
  duration1 = luaL_optinteger(L, SUBJIDX+4, 0); /* total time without post-processing */

  /* TODO: Factor the stats struct into a timestats and another one for the rest */
  Stats stats = {duration0, duration1, 0, 0, 0, 0};

  Encoder debug_encoder = { debug_Open, debug_Close };
  Encoder byte_encoder = { byte_Open, byte_Close };
  Encoder json_encoder = { json_Open, json_Close };
  Encoder noop_encoder = { noop_Open, noop_Close };
  Encoder encoder;
  switch (etype) {
  case ENCODE_DEBUG: { encoder = debug_encoder; break; } /* Debug output */
  case ENCODE_BYTE: { encoder = byte_encoder; break; }   /* Byte array (compact) */
  case ENCODE_JSON: { encoder = json_encoder; break; }   /* JSON string */
  case ENCODE_LINE: { encoder = noop_encoder; break; }	 /* only checks for abend */
  default: { luaL_error(L, "bad encoder value"); return 0; } /* 'return' suppresses errors */
  }

  Match *match = match_new();
  assert( match->data == NULL );
  RBuffer *matchdata = getbuffer(L); /* RBuffer now on lua stack */
  match->data = *matchdata;	     /* Installed in match struct for reuse */
  
  int err = vm_match(&chunk, input, start, encoder, match, &stats);

  if (err) {
    match_free(match);
    const char *msg = STRERROR(err, MATCH_MESSAGES);
    luaL_error(L, msg);
  }

  if (etype == ENCODE_LINE) {
    assert( match->data->n == 0 );	/* noop_encoder generates no output */
    /* expand output buffer if necessary */
    if (!buf_prepsize(match->data, input->n)) return MATCH_OUT_OF_MEM;
    /* copy input into output buffer */
    buf_addlstring_UNSAFE(match->data, input->data, input->n);
  }

  if (free_input) free(input);
  
  /* Match data buffer still on stack from call to vm_match */
  if (!match->matched) lua_pushinteger(L, 0); /* indicate no match */
  lua_pushinteger(L, match->leftover);	      /* leftover chars */
  lua_pushboolean(L, match->abend);
  lua_pushinteger(L, stats.total_time);
  lua_pushinteger(L, stats.match_time);
  match_free(match);		 /* Does NOT free the data buffer (still on stack) */
  return 5;			 /* success => 3 values on the stack */
}

int r_match_lua (lua_State *L);
int r_match_lua (lua_State *L) {
  return do_r_match(L, 1);
}

int r_match_C (lua_State *L) {
  return do_r_match(L, 0);
}

/*
** {======================================================
** Library creation and functions not related to matching
** =======================================================
*/

static int lp_version (lua_State *L) {
  lua_pushstring(L, VERSION);
  return 1;
}


static int lp_type (lua_State *L) {
  if (testpattern(L, 1))
    lua_pushliteral(L, "pattern");
  else
    lua_pushnil(L);
  return 1;
}


int lp_gc (lua_State *L) {
  Pattern *p = getpattern(L, 1);
  if (p->kt) {
    ktable_free(p->kt);		/* ktable */
  }
  realloccode(L, p, 0);		/* delete code block */
  return 0;
}

static struct luaL_Reg pattreg[] = {
  {"ptree", lp_printtree},
  {"pcode", lp_printcode},
  {"B", lp_behind},
  {"V", lp_V},
/*   {"C", lp_simplecapture}, */
/*   {"Cp", lp_poscapture}, */
  {"P", lp_P},
  {"S", lp_set},
  {"R", lp_range},
  {"version", lp_version},
  {"type", lp_type},
  /* Rosie-specific functions below */
  {"Halt", lp_halt},		/* rosie */
  {"saveRPLX", lp_saveRPLX},
  {"loadRPLX", lp_loadRPLX},
  {"usize", r_userdata_size},
  {"psize", r_pattern_size},
  {"codegen", r_codegen_if_needed},
  {"rcap", r_capture},
  {"rconstcap", r_constcapture},
  {"Br", r_backref},
  {"rmatch", r_match_lua},
  {"newbuffer", r_lua_newbuffer},
  {"getdata", r_lua_getdata},
  {"writedata", r_lua_writedata},
  {"add", r_lua_add},
  {"decode", r_lua_decode},
  {NULL, NULL}
};

static struct luaL_Reg metareg[] = {
  {"__mul", lp_seq},
  {"__add", lp_choice},
  {"__pow", lp_star},
  {"__gc", lp_gc},
  {"__len", lp_and},
/*{"__div", lp_divcapture}, */
  {"__unm", lp_not},
  {"__sub", lp_sub},
  {NULL, NULL}
};


int luaopen_lpeg (lua_State *L);
int luaopen_lpeg (lua_State *L) {
  luaL_newmetatable(L, PATTERN_T);
  luaL_setfuncs(L, metareg, 0);
  luaL_newlib(L, pattreg);
  lua_pushvalue(L, -1);
  lua_setfield(L, -3, "__index");
  return 1;
}

/* }====================================================== */
