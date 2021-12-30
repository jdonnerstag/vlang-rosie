
### What is different in v3

I want to test the following ideas:
- we need to reduce the amount of captures. Please see the global todo file for details
- Currently a command is 8 bits, and 24 bits auxillary
  - to access aux, we need to shift the value by 8 bits. Does it make a difference to move the byte code to the upper byte?
  - Does it make a difference to not mix byte code and aux, but rather have them in separate slots?