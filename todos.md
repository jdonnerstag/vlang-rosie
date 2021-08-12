
- captures are not yet really tested, especially for deeper structures.
   - we also need a kind of streaming approach for captures
- missing functions/macros are findall, and keepto, message and error
- Improve error messages with file, lineno, and possibly context. See V's compiler error messages, which I think are very good.
- Test that for ~ and . and may be others, the defaults can be replaced.
- the utf-8 rpl files has plenty of '[\\x12][\\x34]'. It should return a char respectively a string for multiple consequtive
    ones, rather then a (multiple) charsets
- backref is not yet implemented
- we not yet determine rosie's home dir, if installed, to determine ./rpl directory
- we do not support ~/.rcfile or similar yet  (which is used for REPL only ?!?)
- "<!(pat)" is equivalent to "!(pat)".  Raise a warning, to inform the user about a possible mistake. They may want
    "!<(pat)" instead
- Currently the byte code generated is quite generic with plenty room for optimizations
- Same as Jamie's original implementation, upon compilation all code gets expanded. Byte code "function" are not used.
    - Each an every Charset is copied into the byte code. A simple improvement would be to create static charsets
      in the symbol table and refer to the entries instead.
- Allow multiple entry points into the byte code. 
