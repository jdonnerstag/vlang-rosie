/*  -*- Mode: C/l; -*-                                                       */
/*                                                                           */
/*  ktable-macros.h                                                          */
/*                                                                           */
/*  © Copyright Jamie A. Jennings 2018.                                      */
/*  LICENSE: MIT License (https://opensource.org/licenses/mit-license.html)  */
/*  AUTHOR: Jamie A. Jennings                                                */

#if !defined(ktable_macros_h)
#define ktable_macros_h

#if !defined(DEBUG_OUTPUT)
#define DEBUG_OUTPUT 0
#endif

#if DEBUG_OUTPUT
#define LOG(msg)							\
  do { fprintf(stderr, "%s:%d:%s(): %s", __FILE__, __LINE__, __func__, msg); \
    fflush(stderr); } while (0)

#define LOGf(fmt, ...)							\
  do { fprintf(stderr, "%s:%d:%s(): " fmt, __FILE__, __LINE__, __func__, __VA_ARGS__); \
    fflush(stderr); } while (0)

#define LOGstack(L)							\
  do { fprintf(stderr, "%s:%d:%s(): lua stack dump: ", __FILE__, __LINE__, __func__); \
    stackDump(L);							\
    fflush(stderr);							\
  } while (0)

static void stackDump (lua_State *L) {
  int i;
  int top = lua_gettop(L);
  if (top==0) { fprintf(stderr, "EMPTY STACK\n"); return;}
  for (i = top; i >= 1; i--) {
    int t = lua_type(L, i);
    switch (t) {
    case LUA_TSTRING:  /* strings */
      fprintf(stderr, "%d: '%s'", i, lua_tostring(L, i));
      break;
    case LUA_TBOOLEAN:  /* booleans */
      fprintf(stderr, "%d: %s", i, (lua_toboolean(L, i) ? "true" : "false"));
      break;
    case LUA_TNUMBER:  /* numbers */
      fprintf(stderr, "%d: %g", i, lua_tonumber(L, i));
      break;
    default:  /* other values */
      fprintf(stderr, "%d: %s", i, lua_typename(L, t));
      break;
    }
    fprintf(stderr, "  ");
  }
  fprintf(stderr, "\n");
}

#else

#define LOG(msg)
#define LOGf(fmt, ...)
#define LOGstack(L)

#endif


/* is the item in the lua stack at idx the right type to be a ktable */
#define isktable(L, idx) lua_islightuserdata((L), (idx))

#define getktable(L, p) do \
    { /* first check type of pattern at stack index p */		\
      Pattern *pat = (Pattern *)luaL_checkudata((L), (p), PATTERN_T);	\
      /* get the ktable, put it on top of the stack */			\
      lua_pushlightuserdata((L), pat->kt);				\
    } while (0)


/* ktable on top of stack; set it as the ktable of pattern at index p */
#define setktable(L, p) do						\
    { Pattern *pat = (Pattern *) luaL_checkudata((L), (p), PATTERN_T); \
      if (!isktable(L, -1)) luaL_error(L, "setktable: did not find ktable on top of stack"); \
      ktable_free(pat->kt);						\
      pat->kt = (Ktable *)lua_touserdata((L), -1);			\
      lua_pop((L), 1);							\
    } while (0)

/* create new (empty) ktable; push it onto lua stack */
#define pushnewktable(L, n) do			\
    { Ktable *kt = ktable_new((n), (n)*30);	\
      if (DEBUG_OUTPUT) ktable_dump(kt);	\
      lua_pushlightuserdata(L, (void *) kt);	\
    } while (0)

/* get element i from ktable at position idx of lua stack,
 * and push it on the stack
 */
#define ktable_get(L, idx, i) do \
    { if (!isktable((L), (idx))) { 					\
	LOGf("macro ktable_get: idx = %d, item #i = %d\n", idx, i);	\
	LOGstack(L);							\
	luaL_error((L), "%s:%d: did not get right type for ktable", __FILE__, __LINE__); \
      }									\
      Ktable *_kt = (Ktable *)lua_touserdata((L), (idx));		\
      size_t _len;							\
      const char *_name = ktable_element_name(_kt, (i), &_len);		\
      if (_name) lua_pushlstring((L), _name, _len);			\
      else {								\
	LOG("nil ktable value\n");					\
	lua_pushnil((L)); }						\
    } while (0)


#endif

