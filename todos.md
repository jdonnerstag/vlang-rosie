
- The builtin package and the placeholders exists, but not the pattern yet for ".", "$", "^", "~"
- Improve error messages with file, lineno, and possibly context. See V's compiler error messages, which I think are very good.
- I don't yet understand how to switch between non-ascii and ascii mode. At least word-boundary and "." have
    different meanings, and probably make testing more easy at the beginning.
    In my current implementation, defaults may go into builtin, and could be overriden with package variables, which
    are searched first.
- In compiler backend we test against the byte code generated. May be it would be more suitable to actually do a match
    and compare the captures. Especially since we may not apply the same optimizations that the original compiler does.
- the utf-8 rpl files has plenty of '[\\x12][\\x34]'. It should return a char resp. string for multiple consequitive ones,
    rather then a (multiple) charsets
- functions/macros are not yet implemented at all, e.g. find, findall, ci, keepto, ...
- meesages and errors are not yet implemented
- backref is not yet implemented
- we not yet determine rosie's home dir, if installed to get ./rpl directory
- we do not support ~/.rcfile or similar yet  (which is used for REPL only ?!?)
