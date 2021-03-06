## V 0.1.10
- Started with CLI
- Added rc-file (~/.rosierc) support
- Started with a benchmark module
- Introduced byte code instructions for ".", "~", [:digit:] for better performance, and more readable byte code.
- Introduced byte code instructions "until_char" and "until_set" to speed up "find", "keepto" and "findall" macros
- Compiler supports manually overriding which variables are captured (to improve performance)
- Support for global builtin overrides
- Support for multiple entry-points in the byte code
- Started with an Engine to plug & play with the different parser and compiler versions available
- Moved Expander into a separate module
- Support pre-compiled *.rplx files (e.g. ./rpl/rosie/rpl_1_3_jdo.rplx), which is now the default for the RPL parser itself
- Added a new parser for RPL-3.0, which is my attempt to bring the pattern language to the next level
- Added a MasterParser which is able to switch automatically between the different parsers, depending on the rpl
  language version. This way, the RPL-3.x parser is able to import RPL-1.x files from the library.
- Added a 'halt' macro which yields a 'halt' byte code instruction, and captures the client-pattern. It also
  allows to continue parsing afterwards. This is intended for 'rpl 1.3' and line-based inputs (e.g. CSV files)
- Added a quote macro and byte-code instruction, because it is such a common case
- Added an until macro, which e.g. allows to move forward to the next line (or eof). This is nice for
  comments, rest-of-line (syntax error), or CSV files.
- Added few more meta-data to the rplx file
- The RPL-1.3 parser byte code is now loaded via $embed_file(), so that in prod mode it doesn't need to
  be loaded from file. Now the exe is fully self-contained.
- Added -show_timings option to some CLI subcomands (e.g. compile)

## V 0.1.9
- Fixed issues with "(a)+" like pattern. See https://gitlab.com/rosie-pattern-language/rosie/-/issues/123
- Clarified back-reference resolution process. See https://gitlab.com/rosie-pattern-language/rosie/-/issues/121
- Complete rebuild of disjunctions, such as `[..]` and `[^ ..]`

## V 0.1.8
- This is the first version, that passes all original Rosie RPL (inline) unittests (see ./rpl)
- Added capture callback function, to allow clients to receive capture "streams"
- Added support for VM function calls with ok/err support. Which is now the default for word-boundary (~).
   Theoretically that should allow multiple entry points as well, but hasn't been tested yet.

## V 0.1.5
- We now have a core 0 parser, byte code compiler, virtual runtime and disassembler
- predicate, multiplieres, word-boundary, choices, eof and bof are implemented and seem to be working.
  There are numerous tests in each package.

## V 0.1.0
- So far this is merely a proof-of-concept
- The virtual machine (runtime) seems to be working, but testing is still a bit akward. It is alpha may be
- Since generating the byte-code is a bit akward, I looked at the compile backend, but that prooved difficult
- So started with a core 0 parser. Written in V-lang, it is not yet leveraging the runtime. The objective is to use
  the runtime though. Hence the core 0 parser is not written with correctness in mind, and error handling is
  probably a bit weak as well.