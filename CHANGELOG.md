## V 0.1.0
- So far this is merely a proof-of-concept
- The virtual machine (runtime) seems to be working, but testing is still a bit akward. It is alpha may be
- Since generating the byte-code is a bit akward, I looked at the compile backend, but that prooved difficult
- So started with a core 0 parser. Written in V-lang, it is not yet leveraging the runtime. The objective is to use
  the runtime though. Hence the core 0 parser is not written with correctness in mind, and error handling is
  probably a bit weak as well.