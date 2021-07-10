/*  -*- Mode: C; -*-                                                         */
/*                                                                           */
/*  rbuf.c   Custom version of luaL_Buffer, uses buf.c                       */
/*                                                                           */
/*  © Copyright Jamie A. Jennings, 2018.                                     */
/*  © Copyright IBM Corporation 2017.                                        */
/*  LICENSE: MIT License (https://opensource.org/licenses/mit-license.html)  */
/*  AUTHOR: Jamie A. Jennings                                                */

#include <string.h>
#include <stdlib.h>

#include "buf.h"

#include "lua.h"
#include "lauxlib.h"
#include "rbuf.h"

/* --------------------------------------------------------------------------------------------------- */

/* returns a pointer to a free area with at least 'sz' bytes */
char *r_prepbuffsize (lua_State *L, RBuffer *rb, size_t sz) {
  Buffer *b = *rb;
  char *next = buf_prepsize(b, sz);
  if (!next) {
    int info = buf_info(b);
    if (info & BUF_IS_LITE) luaL_error(L, "cannot expand wrapped buffer");
    else luaL_error(L, "out of memory");
  }
  return next;
}

/* --------------------------------------------------------------------------------------------------- */

static int buffgc (lua_State *L) {
  /* top of stack is 'self' for gc metamethod */
  Buffer *buf = *( (RBuffer *)lua_touserdata(L, 1) );
  buf_free(buf);		/* free the data, if it was malloc'd */
  free(buf);			/* free the buffer structure itself */
  return 0;
}

static int buffsize (lua_State *L) {
  Buffer *buf = *( (RBuffer *)luaL_checkudata(L, 1, ROSIE_BUFFER) );
  lua_pushinteger(L, buf->n);
  return 1;
}

int r_lua_buffreset (lua_State *L, int pos) {
  Buffer *buf = *( (RBuffer *)luaL_checkudata(L, pos, ROSIE_BUFFER) );
  buf_reset(buf);
  return 0;
}

static int r_buffsub (lua_State *L) {
  Buffer *buf;
  int j = 1;
  int k = luaL_checkinteger(L, -1);
  int two_indices = lua_isinteger(L, -2);
  if (two_indices) {
    j = lua_tointeger(L, -2);
    buf = *( (RBuffer *)luaL_checkudata(L, -3, ROSIE_BUFFER) );
    lua_pop(L, 3);
  }
  else {
    j = k;
    buf = *( (RBuffer *)luaL_checkudata(L, -2, ROSIE_BUFFER) );
    k = buf->n;
    lua_pop(L, 2);
  }
  size_t len;
  char* str = buf_substring(buf, j, k, &len);
  lua_pushlstring(L, str, len);
  return 1;
}

int r_lua_getdata (lua_State *L);

static struct luaL_Reg rbuf_meta_reg[] = {
    {"__gc", buffgc},
    {"__len", buffsize},
    {"__tostring", r_lua_getdata},
    {NULL, NULL}
};

static struct luaL_Reg rbuf_index_reg[] = {
    {"sub", r_buffsub},
    {NULL, NULL}
};

static void rbuf_type_init(lua_State *L) {
  /* Enter with a new metatable on the stack */
  int top = lua_gettop(L);
  luaL_setfuncs(L, rbuf_meta_reg, 0);
  luaL_newlib(L, rbuf_index_reg);
  lua_pushvalue(L, -1);
  lua_setfield(L, -3, "__index");
  lua_settop(L, top);
  /* Must leave the metatable on the stack */
}

RBuffer *r_newbuffer (lua_State *L) {
  Buffer *buf = buf_new(0);
  RBuffer *rbuf = lua_newuserdata(L, sizeof(*buf));
  *rbuf = buf;			/* store pointer to buf */
  if (luaL_newmetatable(L, ROSIE_BUFFER)) rbuf_type_init(L);
  lua_setmetatable(L, -2);	 /* pops the metatable, leaving the userdata at the top */
  return rbuf;
}

RBuffer *r_newbuffer_wrap (lua_State *L, char *data, size_t len) {
  Buffer *buf = buf_from_const(data, len);
  RBuffer *rbuf = lua_newuserdata(L, sizeof(*buf));
  *rbuf = buf;			/* store pointer to buf */
  if (luaL_newmetatable(L, ROSIE_BUFFER)) rbuf_type_init(L);
  lua_setmetatable(L, -2);	/* pops the metatable, leaving the userdata at the top */
  return rbuf;
}

void r_addlstring (lua_State *L, RBuffer *rb, const char *s, size_t l) {
  Buffer *b = *rb;
  Buffer *buf = buf_addlstring(b, s, l);
  if (!buf) {
    int info = buf_info(b);
    if (info & BUF_IS_LITE) luaL_error(L, "cannot expand wrapped buffer");
    else luaL_error(L, "out of memory");
  }
}

void r_addint (lua_State *L, RBuffer *rb, int i) {
  Buffer *b = *rb;
  Buffer *buf = buf_addint(b, i);
  if (!buf) {
    int info = buf_info(b);
    if (info & BUF_IS_LITE) luaL_error(L, "cannot expand wrapped buffer");
    else luaL_error(L, "out of memory");
  }
}

/* Unsafe: caller to ensure that read will not pass end of buffer */
int r_readint(const char **s) {
  return buf_readint(s);
}

/* Unsafe: caller to ensure that read will not pass end of buffer */
int r_peekint(const char **s) {
  return buf_peekint(*s);
}

void r_addshort (lua_State *L, RBuffer *rb, short i) {
  Buffer *b = *rb;
  Buffer *buf = buf_addshort(b, i);
  if (!buf) {
    int info = buf_info(b);
    if (info & BUF_IS_LITE) luaL_error(L, "cannot expand wrapped buffer");
    else luaL_error(L, "out of memory");
  }
}

/* Unsafe: caller to ensure that read will not pass end of buffer */
int r_readshort(const char **s) {
  return buf_readshort(s);
}

int r_lua_newbuffer(lua_State *L) {
  r_newbuffer(L);		/* leaves buffer on stack */
  return 1;
}

int r_lua_getdata (lua_State *L) {
  Buffer *buf = *( (RBuffer *)luaL_checkudata(L, 1, ROSIE_BUFFER) );
  lua_pushlstring(L, buf->data, buf->n);
  return 1;
}

int r_lua_writedata(lua_State *L) {
    FILE *fp = *(FILE **) luaL_checkudata(L, 1, LUA_FILEHANDLE);
    Buffer *buf = *( (RBuffer *)luaL_checkudata(L, 2, ROSIE_BUFFER) );
    if (buf_write(fp, buf) != BUF_OK)
      luaL_error(L, "writedata: write error (buffer %p, size %d)", buf->data, buf->n);
    return 0;
}

int r_lua_add (lua_State *L) {
  size_t len;
  const char *s;
  RBuffer *rbuf = (RBuffer *)luaL_checkudata(L, 1, ROSIE_BUFFER);
  s = lua_tolstring(L, 2, &len);
  r_addlstring(L, rbuf, s, len);
  return 0;
}
