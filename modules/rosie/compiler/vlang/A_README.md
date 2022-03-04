
# A RPL V-lang compiler backend

The whole RPL module is meant to be flexible. I wanted to support different parsers,
different RPL language versions, different optimizers, and also different compiler
backends. The first compiler backend was based a virtual machine and specialised
byte code instructions which it executes. The RPL compiler backend generates the
byte code matching the pattern to be parsed. This backend generates V-lang source
code instead.

# Testing

Since this backend generates V-lang source code, it must also be compiled. Otherwise
I would not be able to test it. Doing this for possibly hundreds of tests is slow
and awkward. So I thought why not generate the V-lang test cases as well. RPL unit-tests
(-- test ..) already existed.

As an additional benefit, I would not only use them for the RPL Vlang compiler, but I
could leverage them across all backends, certainly improving consistency and quality.
Because they are now *common*, I copied them to './rpl/rosie/tests'

Testing the RPL vlang compiler now works like this:
  1. For every *.rpl file in ./rpl/rosie/tests
  	- parse it and generate the vlang code
    - parse the unittests it contains and generate respective vlang test functions
  2. Run all the generated test files, implicitely compiling the V-lang source code generated


# CLI

Please note that it is also possible to use the CLI to compile an RPL file in V-lang
source code.

```
..\v\v.exe run rosie_cli.v compile -c vlang -o .\temp\gen\modules\mytest .\modules\rosie\compiler\vlang\chars_tests.rpl t1

set VMODULES=.\modules;.\temp\gen\modules

..\v\v.exe -keepc -cg test .\temp\gen\modules\mytest\chars_tests_test.v
```
