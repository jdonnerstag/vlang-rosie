
- leverage V-lang bitfield for charsets
- some macros are missing yet, e.g. message and error
- the utf-8 rpl files has plenty of '[\\x12][\\x34]'. Currently it create a Charset per byte. We should be able to
    optimize it and convert them automatically into chars and/or strings respectively.
- we not yet determine rosie's home dir, if installed, to determine ./rpl directory
- we do not support ~/.rcfile or similar yet  (which is used for REPL only ?!?)
- "<!(pat)" is equivalent to "!(pat)".  Raise a warning, to inform the user about a possible mistake. They may want
    "!<(pat)" instead
- Currently the byte code generated is quite generic with plenty room for optimizations
- I don't understand yet what # tags are in RPL and byte code they produce
- Jamie's original implementation, always inlines variables.
    - We have a first version of a function call, which is already used for word_boundary (return value yes, parameters no).
      But user's can not use it yet.
    - Same for multiple entry points. Exists, but the source code is still rough
    - Each and every Charset is copied into the byte code. A simple improvement would be to create static charsets
      in the symbol table and refer to the entries instead.
    - Does Jamie have string functions? Would it be benefical?
- Research: I wonder whether byte codes, much closer to RPL, provide value. And if it's only for readability
      Not sure for "choice", and also not sure for multiplieres.
      May be for predicates?
      I'm hoping for more optimization options, with higher level byte code instructions
- Many times we open new captures, only to fail on the first char. Could this be optimized?
    E.g. Test the first char, and if successful, only then open the capture, obviously including
    the char already tested.
- to be confirmed: imagine parsing a large html file, or large CSV file. Millions of captures will be created.
    Even only the matched captures will be huge. We need something much more efficient for these use cases:
    E.g. only keep the stack of open parent captures, but remove everything else. (backref won't work anymore).
    In CSV, reading line by line can be external, with a fresh match per line. But that won't work for html.
    (and html does require backrefs).
    May be a complete streaming approach: the VM keeps just the minimum of capture absolutely needed,
    but publishes (or callback) every capture to the client, so that the user can decided what to do with them.
- Using rosie lang gitlab issues; i had good discussions with Jamie on RPL and some features. We definitely should
    try to build some of them into the platform.
- I keep on thinking about "case insensitive", and whether there are better approaches then expanding the pattern
    from "a" to {"a" / "A"}. It bloates the byte codes quite a bit. May be the parser just converts to lower, and
    the VM converts the byte being processed to a lower char? Would that work with utf-chars? Probably not. So may
    be a combined approach: if utf then ... else ...
    We may add byte code instruction like test_char_ci, char_ci etc., which would bloat the VM quite a bit.
    I'm wondering whether the approach described above, and a "ci_start", "ci_stop" instruction would work? ci_start
    enabling that the byte under investigation will be converted to lower, before analysing it. This "test if ci is needed" would negatively impact the performance for none-ci use cases. I wonder how big that hit really is?!?
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
- we need tests for message and error
- Leverage rosie parser/rpl, to parse rpl input (and compared performance)
- Research: a compiler backend that generates V-code, rather then VM byte code (and compare performance)
- utf8: not sure, utf8 is already properly tested; utf-8 in RPL and also input data
- Small charset optimizations
  - ci:{"a"} == [aA] == {"a" / "A"}. The 256 bit charset is not especially lightweight, neither is
    a standard "choice", such as
       choice
       char "a"
       commit jmp to X
       char "b"
    Simpler and hence faster would probably be something like
       if_char "a" jmp to X
       char "A"
    but 'if_char' byte code instruction doesn't exist yet. Only 'test_char' does, which jumps upon error.
    The approach doesn't need to be restricted to 2 chars as in the case-insentive use case. Consider [:space:],
    has 5 bytes. Perf-tests shall be used to identify the optimum, whether 'set' is faster or
       if_char "\n" jmp to X
       if_char "\r" jmp to X
       if_char "\t" jmp to X
       ...
       char " "
  - Another thought might be: instead of charset, provide a (new) instruction such as:
        E.g. set_in "\r\n\t ". The bytes follow the instructions (probably 4 8 etc.)
        I'm only wondering whether efficient x86 asm exists for this?
  - Currently Charset is a 256 bit-set => 32 bytes (16 words). Many times it is [:ascii:] and the upper 16 bytes
        (128 - 255) are all empty. We may provide "shorter" Charsets, and e.g. leverage 'aux' to denote whether
        it is long or short. Not sure it will eventually be faster, but definitely more space efficient.
        Especially since Charsets are currently all inlined.
  - We may also provide users the choice to use a 256 byte (or 128 byte) lookup table. Obviously it takes more
        space, but it would definitely be faster. May be macros could be used to control this.
  - Also [:ascii:] could be optimized, as it only needs to test bit-7. Charset is definitely heavy weight for it.
  - [:alnum:] and few more might also benefit from optimized byte code instructions, which have the tests
      hard-coded 'if x > 64 and x < 92' ...
- String byte codes
    We may create 'string' byte codes with flexible length, but may be the following is more perf-optimized.
    int64 and int32 contain 8 respectively 4 bytes (chars). We could load the next slot (4 bytes) into a CPU
    register and compare 4 bytes at ones, rather then one byte after another. So instead of `str "my_text"'
    we would do:
        char_4 "my_t"
        char "e"
        char "x"
        char "t"
    However it might also be, that the underlying C-libs, or x86 CPU instructions already optimize? => benchmarks needed.
    Remember when doing (real) benchmark, to use V's -prod flag for the C-compiler to generate optimized x86 byte codes.