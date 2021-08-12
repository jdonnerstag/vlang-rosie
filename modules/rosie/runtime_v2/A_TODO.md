
Note that runtime_v1 and runtime_v2 do not share common interfaces. Hence they are not
easily interchangeable.  It is more of an evolution. V1 is pretty much based on the
original Rosie C-implementation. V2 is an evolution of it.

# This is a todo list

- I don't understand yet what # tags are in RPL and byte code they produce
- test grammars examples
- Add benchmark and profile test, also to compare how they trend upon changes
  - I'd like to have benchmarks/profiles/trends of the VM runtime matching specific patterns and input
  - I'd like to have a "./rosie grep .." based comparison, even though that including reading the file, compilation, etc.
- add test with findall: macro
