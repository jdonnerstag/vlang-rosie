/*
** $Id: lptypes.h,v 1.14 2015/09/28 17:17:41 roberto Exp $
** LPeg - PEG pattern matching for Lua
** Copyright 2007-2015, Lua.org & PUC-Rio  (see 'lpeg.html' for license)
** written by Roberto Ierusalimschy
*/

#if !defined(lptypes_h)
#define lptypes_h


#if !defined(LPEG_DEBUG)
#define NDEBUG
#endif

#include <assert.h>
#include <limits.h>

#include "lua.h"


#define VERSION         "1.0.0"
#define PATTERN_T	"lpeg-pattern"

/*
** compatibility with Lua 5.1
*/
#if (LUA_VERSION_NUM == 501)

#define lp_equal	lua_equal

#define lua_getuservalue	lua_getfenv
#define lua_setuservalue	lua_setfenv

#define lua_rawlen		lua_objlen

#define luaL_setfuncs(L,f,n)	luaL_register(L,NULL,f)
#define luaL_newlib(L,f)	luaL_register(L,"lpeg",f)

#endif

#if !defined(lp_equal)
#define lp_equal(L,idx1,idx2)  lua_compare(L,(idx1),(idx2),LUA_OPEQ)
#endif


/* Initial size for call/backtrack stack in lpvm.c */
#define INITSTACK	200

/* Rosie: MAXSTACKIDX can be at most USHRT_MAX */
#define MAXSTACKIDX     USHRT_MAX


/* maximum number of rules in a grammar 
 * STACK ALLOCATED array of ints of this size in codegrammar() in lpcode.c
 */
#if !defined(MAXRULES)
#define MAXRULES        1000
#endif

/* #define MAXCAPIDX USHRT_MAX */
/* typedef unsigned short capidx_t;  */
/* #define MAXCAPIDX 1000 * 1000 /\* at most can be 2147483647 for signed int32 *\/ */
/* typedef int32_t capidx_t;  */


/* initial size for capture's list 
 * 
 * FUTURE: Tune this value to accomodate most use cases (32 may be
 * good -- need to track actual usage to know).
 */
#define INITCAPSIZE	2000


/* index, on Lua stack, for subject */
#define SUBJIDX		2

/* number of fixed arguments to 'match' (before capture arguments) */
#define FIXEDARGS	3

/* index, on Lua stack, for capture list */
/* #define caplistidx(ptop)	((ptop) + 2) */

/* index, on Lua stack, for pattern's ktable */
/* #define ktableidx(ptop)		((ptop) + 3) */

/* index, on Lua stack, for backtracking stack */
/* #define stackidx(ptop)	((ptop) + 4) */



#define loopset(v,b)    { int v; for (v = 0; v < CHARSETSIZE; v++) {b;} }

/* access to charset */
#define treebuffer(t)      ((byte *)((t) + 1))

/* number of slots needed for 'n' bytes */
#define bytes2slots(n)  (((n) - 1) / sizeof(TTree) + 1)

/* set 'b' bit in charset 'cs' */
#define setchar(cs,b)   ((cs)[(b) >> 3] |= (1 << ((b) & 7)))


/*
** in capture instructions, 'kind' of capture and its offset are
** packed in field 'aux', 4 bits for each
*/
//#define getkind(op)		((op)->i.aux & 0xF)
//#define getoff(op)		(((op)->i.aux >> 4) & 0xF)
//#define joinkindoff(k,o)	((k) | ((o) << 4))

//#define MAXOFF		0xF
//#define MAXAUX		0xFFFF	/* aux field of instruction is 'short' */


/* maximum number of bytes to look behind */
#define MAXBEHIND	0x7FFF	/* INST_ADDR_MAX at most */


/* maximum size (in elements) for a pattern */
#define MAXPATTSIZE	(SHRT_MAX - 10)


/* size (in elements) for an instruction plus extra l bytes */
#define instsize(l)  (((l) + sizeof(Instruction) - 1)/sizeof(Instruction) + 1)


/* size (in elements) for a ISet instruction */
#define CHARSETINSTSIZE		instsize(CHARSETSIZE)

/* size (in elements) for a IFunc instruction */
#define funcinstsize(p)		((p)->i.aux + 2)



#define testchar(st,c)	(((int)(st)[((c) >> 3)] & (1 << ((c) & 7))))


#endif

