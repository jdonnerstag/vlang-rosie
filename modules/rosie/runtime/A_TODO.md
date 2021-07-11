# This is a todo list

- test back-reference to a capture
- a match may not consume the full input. Test how to continue with a 2nd match.
- I don't understand yet what # tags are in RPL and byte code they produce
- test grammars examples
- Add benchmark and profile test, also to compare how they trend upon changes
  - I'd like to have benchmarks/profiles/trends of the VM runtime matching specific patterns and input
  - I'd like to have a "./rosie grep .." based comparison, even though that including reading the file, compilation, etc.
- add test with findall: macro
- I don't think we yet have RPL for all possible byte code instructions. We somehow need to reverse engineer the RPL
  compiler to find the RPL that generates them.


# Notes:

find:{ net.any <".com" }   creates 313882 byte code instructions ?!?!?  And in case of a mismatch a large (61) capture list
