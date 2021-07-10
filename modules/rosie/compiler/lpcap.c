/*  -*- Mode: C/l; -*-                                                       */
/*                                                                           */
/*  lpcap.c                                                                  */
/*                                                                           */
/*  © Copyright Jamie A. Jennings 2018.                                      */
/*  LICENSE: MIT License (https://opensource.org/licenses/mit-license.html)  */
/*  AUTHORS: Jamie A. Jennings, roberto (see below)                          */
/*
** $Id: lpcap.c,v 1.6 2015/06/15 16:09:57 roberto Exp $
** Copyright 2007, Lua.org & PUC-Rio  (see 'lpeg.html' for license)
*/

#include "lua.h"
#include "lauxlib.h"

#include "lpcap.h"
#include "lptypes.h"

#include <string.h>
#include <time.h>

/* #include "rcap.h" */
#include "rpeg.h"
#include "ktable.h" 
#include "ktable-macros.h"

#define check_bounds(s,e) if (*(s) > *(e)) luaL_error(L, "corrupt match data (buffer overrun)");

/* See byte encoder in rcap.c */
static void pushmatch(lua_State *L, const char **s, const char **e, int depth) {
  int top;
  short shortlen;
  int pos;
  int n = 0;
  pos = r_readint(s);
  check_bounds(s, e);
  
  if ((pos) > 0) luaL_error(L, "corrupt match data (expected start marker)");

  lua_checkstack(L, 4);	        /* match table, key, value, plus one for luaL_error */
  lua_createtable(L, 0, 5);	/* create match table */ 
  lua_pushliteral(L, "s"); 
  lua_pushinteger(L, -(pos)); 
  lua_rawset(L, -3);		/* match["s"] = start position */ 

  shortlen = r_readshort(s);	/* length of typename string */
  if (shortlen <= 0) {
    /* The typename cannot be empty string; neg length (or 0) means
       constant capture. */
    lua_pushliteral(L, "type"); 
    lua_pushlstring(L, *s, (size_t) -shortlen);	
    lua_rawset(L, -3);		/* match["type"] = name */ 
    (*s) += -shortlen;		/* advance to first char after */
    check_bounds(s, e);
    shortlen = r_readshort(s);	/* length of const data string */
    if (shortlen < 0) luaL_error(L, "corrupt match data (expected length of const cap data)");
    lua_pushliteral(L, "data"); 
    lua_pushlstring(L, *s, (size_t) shortlen);	
    lua_rawset(L, -3);		/* match["data"] = const capture value */ 
    (*s) += shortlen;		/* advance to first char after */
    check_bounds(s, e);
  } else {
    /* Regular captures */
    lua_pushliteral(L, "type");
    lua_pushlstring(L, *s, (size_t) shortlen);	
    lua_rawset(L, -3);		/* match["type"] = name */ 
    (*s) += shortlen;		/* advance to first char after name */
    check_bounds(s, e);
  }

  /* process subs, if any */
  top = lua_gettop(L);
  while (r_peekint(s) < 0) {
    pushmatch(L, s, e, depth++);
    n++;
  } 
  
  if (n) {    
    lua_createtable(L, n, 0); /* create subs table */     
    lua_insert(L, top+1);     /* move subs table to below the subs */     
    /* fill the subs table (lua_rawseti pops the value as well) */     
    for (int i=n; i>=1; i--) lua_rawseti(L, top+1, (lua_Integer) i);      
    /* subs table now at top. below it: match table */    
    lua_pushliteral(L, "subs");    
    lua_insert(L, -2);		/* move subs table to top of stack */
    lua_rawset(L, -3);		/* match["subs"] = subs table */    
  }    

  pos = r_readint(s);  
  check_bounds(s, e);
  lua_pushliteral(L, "e");  
  lua_pushinteger(L, pos);  
  lua_rawset(L, -3);		/* match["e"] = end position */  
  check_bounds(s, e);

  /* leave match table on the stack */
}
  
int r_lua_decode (lua_State *L) {
  RBuffer *rbuf = (RBuffer *)luaL_checkudata(L, 1, ROSIE_BUFFER); 
  Buffer *buf = *rbuf;
  const char *s = buf->data;	/* start of data */ 
  const char *e = buf->data + buf->n; /* end of data */ 
  lua_Integer t0 = (lua_Integer) clock();
  lua_Integer duration = luaL_optinteger(L, 2, 0); /* time accumulator */
  if (buf->n == 0) lua_pushnil(L);
  else { pushmatch(L, &s, &e, 0); }
  lua_pushinteger(L, ((lua_Integer) clock()-t0)+duration); /* processing time */  
  return 2;
}

