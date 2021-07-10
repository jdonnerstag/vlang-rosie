# Native [Rosie-RPL](https://rosie-lang.org/) implementation in [V-lang](https://vlang.io)

[Rosie](https://rosie-lang.org/) is a pattern language (RPL for short), a little like
regex, but aiming to solve some of the regex issues.

As of today, this V module implements only RPL's runtime which is based on a tiny
virtual machine. RPL source files '*.rpl' are compiled into byte code '\*.rplx'. The
runtime is able to read the '\*.rplx' files, exeute the byte code instructions, and thus
determine the captures when matching input data against the pattern.

Even though this module is able to read '\*.rplx' files, it is not designed to replace
Rosie's original implementation. The V module does not expose the same libraries
functions and signatures.

Please note that the '\*.rplx' file structure and neither the byte codes of the virtual
machine are part of Rosie's specification and thus are subject to change without
formal notice from the Rosie team.

This project started as a proof-of-concept aiming at getting pratical experience with V and validate it's promises.

I decided to use Rosie because I like many of it's ideas, and thought it would be a good contributions to V as well.

Obviously I needed to start somewhere, and I decided to start with the RPL runtime. The original RPL runtime is completely written in C, whereas the compiler and frontend is a mixture of C and Lua. The V implementation started as copy of the C-code, gradually introducing more and more V constructs, and also replacing 'unsafe' pointer arithmetics.

I've done any performance or benchmarks yet. That is on my todo list. The current implementation not performance tuned yet. It will be interesting to see, how it compares to the original one.

The RPL compiler has an experimental feature to compile '\*.rpl' source code files into '*.rplx' files. Which allowed me to leverage RPL's standard frontend and compiler, but my own runtime.

Current status is alpha. Even though I keep on adding test cases, there are for sure plenty edge cases which have not been tested yet and may fail.

So far I'm actually quite pleased with the V implementation. I find it much easier to read and maintain then the original C-code.