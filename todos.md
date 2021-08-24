
- missing functions/macros are findall, and keepto, message and error
- the utf-8 rpl files has plenty of '[\\x12][\\x34]'. It should return a char respectively a string for multiple consequtive
    ones, rather then a (multiple) charsets
- backref is not yet implemented. I don't think it is used anywhere in the original rosie code base??
- we not yet determine rosie's home dir, if installed, to determine ./rpl directory
- we do not support ~/.rcfile or similar yet  (which is used for REPL only ?!?)
- "<!(pat)" is equivalent to "!(pat)".  Raise a warning, to inform the user about a possible mistake. They may want
    "!<(pat)" instead
- Currently the byte code generated is quite generic with plenty room for optimizations
- Jamie's original implementation, always inlines variables.
    - We have a first version of a function call, which is already used for word_boundary. But user's can not use it yet.
    - Same for multiple entry points. Exists, but the source code is still rough
    - Each an every Charset is copied into the byte code. A simple improvement would be to create static charsets
      in the symbol table and refer to the entries instead.
