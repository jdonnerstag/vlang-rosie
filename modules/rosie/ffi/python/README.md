
# Objective

How to best integrate V-lang with Python, so that python users can easily install
the v-rosie lib and use it?

- A PyPi module would allow every Python user to easily install the module
  - with pre-build *.so and *.dll files for different environments?
- With an apt package that installs v-rosie incl. CLI etc?
- pyvlang https://github.com/eregnier/pyvlang is a PoC. Could that be adopted
  to provide a v-rosie specific module in python?
- Or should we add a V-lang module, based on python.h, that builds a *.so/*.dll
  that is python enabled? pyvrosie.so?
  - V-lang has no build-system. But we'd need to build the vrosie.exe, pyvrosie.so,
    may be some vrosie.so for generell use
- I've haven't yet figured out how use vrosie as parser for *.rpl, *.c, etc. file,
  especially large files with many captures. May be we start with more simple regex
  like replacements?
- Separate parse & compile step from match.
- Some caching would be great? Is not on the todo list, is it?
  Since vlang has no globals, maybe leverage the RosieConfig struct and add a
  cache variable? Add RosieConfig to every parse, compile, match function, ..
  Since we can have multiple Matches, do not add function to RosieConfig
