## V 0.1.x
- Added capture callback function, to allow clients to receive capture "streams"

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