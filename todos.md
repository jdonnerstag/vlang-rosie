
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
- generate optimized byte code for find:
- provide optimized byte code instruction for "." (any). Read 4 bytes and test in one go against utf ranges
- I wonder whether byte codes, much closer to RPL, provide value. And if it's only for readability
      Not sure for "choice", and also not sure for multiplieres.
      May be for predicates?
      I'm hoping for more optimization options, with higher level byte code instructions
- provide optimized byte code for ~ (word boundary)
- {!pat .}* pat is quite common. find: macro simplifies writing it, but implementations are fairly inefficient.
    pat needs to match twice. I personally think that is a shortcoming of RPL.
- Many times we open new captures, only to fail on the first char. Could this be optimized?
    E.g. Test the first char, and if successful, only then open the capture, obviously including
    the char already tested.
