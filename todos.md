
- functions/macros are not yet implemented at all, e.g. find, findall, ci, keepto, ...
- captures are not yet really tested, especially for deeper structures.
   - we also need a kind of streaming approach for captures
- Improve error messages with file, lineno, and possibly context. See V's compiler error messages, which I think are very good.
- I don't yet understand how to switch between non-ascii and ascii mode. At least word-boundary and "." have
    different meanings, and probably make testing more easy at the beginning.
    In my current implementation, defaults may go into builtin, and could be overriden with package variables, which
    are searched first.
    And it has been tested: E.g. replace "~" for another word_boundary
- the utf-8 rpl files has plenty of '[\\x12][\\x34]'. It should return a char resp. string for multiple consequitive ones,
    rather then a (multiple) charsets
- meesages and errors are not yet implemented
- backref is not yet implemented
- we not yet determine rosie's home dir, if installed to get ./rpl directory
- we do not support ~/.rcfile or similar yet  (which is used for REPL only ?!?)
- "<!(pat)" is equivalent to "!(pat)".  Raise a warning, to inform user about possible mistake. He may wants "!<(pat)" instead
- Currently the byte code generated is quite generic with plenty room for optimizations.