
- some macros are missing yet, e.g. message and error
- we not yet determine rosie's home dir, if installed, to determine ./rpl directory
- CLI does not support ~/.rcfile or similar yet  (which is used for REPL only ?!?)
- "<!(pat)" is equivalent to "!(pat)".  Raise a warning, to inform the user about a possible mistake. They may want
    "!<(pat)" instead
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
    Even the matched captures only will be huge. We need something much more efficient for these use cases:
    E.g. only keep the stack of open parent captures, but remove everything else. (backref won't work anymore).
    In CSV, reading line by line can be external, with a fresh match per line. But that won't work for html.
    (and html does require backrefs).
    May be a complete streaming approach: the VM keeps just the minimum of capture absolutely needed,
    but publishes (or callback) every capture to the client, so that the user can decided what to do with them.
- Using rosie lang gitlab issues; i had good discussions with Jamie on RPL and some features. We definitely should
    try to build some of them into the platform.
- V has an [export] attribute to determine the name for C-function names being exported. Relevant for libraries etc.
    May be that could be a way to develop a compliant librosie.so ??
- I like Jamie's ideas for rpl 2.0 (see several gitlab issue for the discussions)
    - clarify backref resolution process
    - "&" operator currently translates to {>a b}. Either remove "&" completely or make it an optional "and" operator
    - tok:(..) instead of (..)
    - or:(..) instead of [..] (but still supporting "/" operator)
    - no more (), {} and []. Only () for untokenized concatenations. [] replaced with or:() and () replaced
      with tok:() macros. [] only for charsets.
    - make grammar syntax like a package, and recursive an attribute of a binding
- Leverage rosie parser/rpl, to parse rpl input (and compare performance)
- Research: a compiler backend that generates V-code, rather then VM byte code (and compare performance)
- utf8: not sure, utf8 is already properly tested; utf-8 in RPL and also input data
- Another approach to optimize might be avoiding bt-entries. Rather optimzing every instruction, optimize the
  byte code program (the overall number of 'slow' byte codes). E.g. could specific "/" choices be optimzed?
  Certain multiplieres or predicate combinations?
    E.g.
    Instead of
        choice ...
        char 'a'
        char 'b'
    something like
        test_char ..
        any
        choice
        char 'b'
    This may have a positive effect if and when the first char is different between the choice. It will not have an
    effect on string comparisons where several chars at the beginning of the strings are equal.
- I'd like to start working on a VS Code plugin for *.rpl files. It would be something new for me though.
    There is a PoC available in the marketplace, from 2019. Seems dormant and not more then a very quick test,
- The cli is currently using help.txt files. I would really like to avoid them, but I've not yet managed
    to get one of 3? modules working with all the necessary details. The devil has been in the details,
    not the simple demo examples.
- Captures
    I had the thought that we are currently capturing many captures which are not needed. Which means
    unnessary (rather slow) byte code instructions and wasted memory. Searching in all the captures is also
    slower. Currently every non-local non-alias variable will be captured. Required are only the captures
    the user is interested in, and backrefs. Users are not really in control of the lib *.rpl files, hence
    modifying the rpl files is no solution. What if the user would need to provide the name of the vars
    he's actually interested in? The main capture by default will always be captured, but all others
    only by explicit request (additional parameter in the match() function call). Some special value
    might be use to revert to the current behavior.
