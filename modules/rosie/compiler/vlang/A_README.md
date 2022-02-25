
This Compiler generates Vlang code

Testing the RPL vlang compiler is a bit awkward, because it involves
several build and compilation steps:
  - 1st parse the RPL and generate the vlang code
  - 2nd use the Vlang compiler to compile the generate V-code
  - Respectively the test cases validating that the translation did work

Current approach
 - This file defines all the pattern we want to test
 - It also has RPL unittest
 - The compiler will generate V-code for the pattern
 - The compiler will also generate V-code for the unittests
 - The CLI test subcommand will execute the test cases, wrapped into vlang testcase in *_test.v files

An easy way to compile the file is like:
  ..\v\v.exe run rosie_cli.v compile -c vlang -o .\temp\gen\modules\mytest .\modules\rosie\compiler\vlang\test_cases.rpl mypattern

Using the "meta CLI compiler" directive, // TODO not yet implemented
meta CLI compiler -c vlang -o .\temp\gen\modules\mytest *
  ..\v\v.exe run rosie_cli.v compile .\modules\rosie\compiler\vlang\test_cases.rpl
