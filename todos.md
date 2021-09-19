
- some macros are missing yet, e.g. message and error
- the utf-8 rpl files has plenty of '[\\x12][\\x34]'. Currently it create a Charset per byte. We should be able to
    optimize it and convert them automatically into chars and/or strings respectively.
- we not yet determine rosie's home dir, if installed, to determine ./rpl directory
- we do not support ~/.rcfile or similar yet  (which is used for REPL only ?!?)
- "<!(pat)" is equivalent to "!(pat)".  Raise a warning, to inform the user about a possible mistake. They may want
    "!<(pat)" instead
- Currently the byte code generated is quite generic with plenty room for optimizations
- Jamie's original implementation, always inlines variables.
    - We have a first version of a function call, which is already used for word_boundary (return value yes, parameters no).
      But user's can not use it yet.
    - Same for multiple entry points. Exists, but the source code is still rough
    - Each and every Charset is copied into the byte code. A simple improvement would be to create static charsets
      in the symbol table and refer to the entries instead.
    - Does Jamie have string functions?
- generate optimized byte code for find macro. Simple pattern can be optimized to a greater extend.
- provide optimized byte code instruction for "." (any). Read 4 bytes and test in one go against utf ranges
- provide byte code instruction for ~
- Research: I wonder whether byte codes, much closer to RPL, provide value. And if it's only for readability
      Not sure for "choice", and also not sure for multiplieres.
      May be for predicates?
      I'm hoping for more optimization options, with higher level byte code instructions
- '{!pat .}* pat' is quite common. find: macro simplifies writing it, but implementations are fairly inefficient.
    pat needs to match twice. I personally think that is a shortcoming of RPL.
- Many times we open new captures, only to fail on the first char. Could this be optimized?
    E.g. Test the first char, and if successful, only then open the capture, obviously including
    the char already tested.
- to be confirmed: imaging parsing a large html file, or large CSV file. Millions of captures will be created.
    Even the matched captures will be huge. We need something much more efficient for these use cases:
    E.g. only keep the stack of open parent captures, but remove everything else. (backref won't work anymore).
    In CSV, reading line by line can be external, with a fresh match per line. But that won't work for html.
    (and html does require backrefs).
    May be a completely streaming approach: the VM keeps just the minimum of capture absolutely needed,
    but publishes (or callback) every capture to the client, so that the user can decided what to do with them.
- Using rosie lang gitlab issues; i had good discussions with Jamie on RPL and some features. We definitely should
    try to build some of them into the platform.
- I keep on thinking about "case insensitive", and whether there are better approaches then expanding the pattern
    from "a" to {"a" / "A"}. It bloates the byte codes quite a bit. May be the parser just converts it lower, and
    the VM converts the byte being processed to a lower char? Would that work with utf-chars? Probably not. So may
    be a combined approach: if utf then ... else ...
    We may add byte code instruction like test_char_ci, char_ci etc., which would bloat the VM quite a bit.
    I'm wondering whether the approach described above, and a "ci_start", "ci_stop" instruction would work? ci_start
    enabling that the byte under investigation will be converted to lower, before analysing it. This "test if ci is needed"
    would negative impact the performance for none-ci use cases. I wonder how big that hit really is?!?
- we need perf-/benchmark tests, including history, so that we can validate the "optimizations" effect.
- V has an [export] attribute to determine the name for C-function names being exported. Relevant for libraries etc.
    May be that could be a way to develop a compliant librosie.so ??
- I like Jamie's ideas for rpl 2.0 (see several gitlab issue for the discussions)
    - clarify backref resolution process
    - "&" operator currently translates to {>a b}. Either remove "&" completely or make it an optional "and" operator
    - tok:(..) instead of (..)
    - or:(..) instead of [..] (but still supporting "/" operator)
    - no more (), {} and []. Only () for untokenized concatenations. [] replaced with or:() and () replaced
      with tok:() macros
    - make grammar like a package, and recursive an attribute of a binding
