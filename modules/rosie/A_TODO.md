# This is a todo list

- test back-reference to a capture
- a match may not consume the full input. Test how to continue with a 2nd match.
- I don't understand yet what # tags are in RPL and byte code they produce
- test grammars examples

- I don't think we yet have RPL for all possible byte code instructions. We somehow need to reverse engineer the RPL 
  compiler to find the RPL that generates them.

- How will it work with a replace() method? Or will we just support matches?
- some rudimentary performance tests. Possibly leverage V-benchmark capabilities
- re-implement statistics

# Notes:

find:{ net.any <".com" }   creates 313882 byte code instructions ?!?!?
