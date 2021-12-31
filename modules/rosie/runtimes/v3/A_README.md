
### What is different in v3

I want to test the following ideas:
- we need to reduce the amount of captures. Please see the global todo file for details
- Is it actually a good idea to create a new version of the compiler? What is wrong with a git branch? A v3
  makes only sense, if its not an evolution, but actually a different/separate one, that we want to keep
  and maintain (maintaining is effort / cost). E.g. if we change the instruction set in a way that is not
  backwards compatible; or if the change the structure "instruction set" + "auxilliary" in one slot, etc.
