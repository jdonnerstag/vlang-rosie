# Notes

This is the original Rosie runtime. It is able to read and run original rosie '*.rplx'
files (compiled RPL files).

When I say "able to run", then it means that is has passed some initial tests,
but it is by no means thoroughly tested and far from production ready.

Why did I start with a new version:
- I find it very awkward that the capture and backtrack stacks are completely independent.
  It made certain patterns very cumbersome to implement.
- The byte code instructions are probably historically grown. I didn't find them especially
  clean.
  