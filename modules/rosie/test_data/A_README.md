
See https://gitlab.com/rosie-pattern-language/rosie/-/blob/master/src/rpeg/test/README
for explanation how to create *.rplx files

Improvement areas:
 - Building the rplx file is currently manual and awfull
 - Every rplx file can only hold 1 "target", that you need to denote when compiling and saving
 - Charsets seem to be (validate) copied many times. Allow to repeatably reference them
 - E.g. word boundaries create a large number of byte code instructions. Could we use "function calls"?
 - At one point we may think about compiling RPL into V-code, rather then rpeg byte code.
 