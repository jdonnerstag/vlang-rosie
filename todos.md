
- I can redefine dot etc. in my file/package, but it will not be applied to any of the
   rpl lib files. This requires that I update the builtin entry. How to do this? Tests?
   Is this possible in the orig implementation?
- some macros are missing yet, e.g. message and error
- we not yet determine rosie's home dir, if installed, to determine ./rpl directory
- "<!(pat)" is equivalent to "!(pat)".  Raise a warning, to inform the user about a possible mistake. They may want
    "!<(pat)" instead
- I don't understand yet what # tags are in RPL and byte code they produce
- Jamie's original implementation, always inlines variables.
    - We have a first version of a function call, which was already used for word_boundary (return value yes, parameters no)
      before we provided the word_boundary byte code instruction.
    - Same for multiple entry points. Exists, but the source code is still rough => not sure it is working ?!? Any tests?
    - Does Jamie have string functions? Would it be benefical?
- Research: I wonder whether byte codes, much closer to RPL, provide value. And if it's only for readability
      Not sure for "choice", and also not sure for multiplieres.
      May be for predicates?
      I'm hoping for more optimization options, with higher level byte code instructions, but
      I'm absolutely unclear what that might be.
- Many times we open new captures, only to fail on the first char. Could this be optimized?
    E.g. Test the first char, and if successful, only then open the capture, obviously including
    the char already tested.
    May be not put them on the final capture stack, but have a 2nd stack. Only move closed over to the other
    stack?
- to be confirmed: imagine parsing a large html file, or large CSV file. Millions of captures will be created.
    Even the matched captures only will be huge. We need something much more efficient for these use cases:
    E.g. only keep the stack of open parent captures, but remove everything else. (backref won't work anymore).
    In CSV, reading line by line => skipping until newline, might be something useful
    May be a complete streaming approach: the VM keeps just the minimum of capture absolutely needed,
    but publishes (or callback) every capture to the client, so that the user can decided what to do with them.
- Using rosie lang gitlab issues; i had good discussions with Jamie on RPL and some features. We definitely should
    try to build some of them into the platform.
- V has an [export] attribute to determine the name for C-function names being exported. Relevant for libraries etc.
    May be that could be a way to develop a compliant librosie.so ??
- I like Jamie's ideas for rpl 2.0 (see several gitlab issue for the discussions)
    - clarify backref resolution process
    - "&" operator currently translates to {>a b}. Either remove "&" completely or make it an optional "and" operator
    - tok:(..) instead of (..)
    - or:(..) instead of [..] (but still supporting "/" operator)
    - no more (), {} and []. Only () for untokenized concatenations. [] replaced with or:() and () replaced
      with tok:() macros. [] only for charsets.
    - make grammar syntax like a package, and recursive an attribute of a binding
- Leverage rosie parser/rpl, to parse rpl input (and compare parser performance)
- Research: a compiler backend that generates V-code, rather then VM byte code (and compare performance)
    you can generate .v code, then compile it and run it yourself -
    @VEXE gives you the path to the V executable, so you can do
    os.system('${@VEXE} run generated_code.v')
- utf8: not sure, utf8 is already properly tested; utf-8 in RPL and also input data
- Another approach to optimize might be avoiding bt-entries. Rather then optimzing every instruction, optimize the
  byte code program (the overall number of 'slow' byte codes). E.g. could specific "/" choices be optimzed?
  Certain multiplieres or predicate combinations?
    E.g.
    Instead of
        choice ...
        char 'a'
        char 'b'
    something like
        test_char ..
        any
        choice
        char 'b'
    This may have a positive effect if and when the first char is different between the choice. It will not have an
    effect on string comparisons where several chars at the beginning of the strings are equal.
- I'd like to start working on a VS Code plugin for *.rpl files. It would be something new for me though.
    There is a PoC available in the marketplace, from 2019. Seems dormant and not more then a very quick test,
- documentation, documentation, documentation, ...
- Some sort of streaming interface for the input data. Not sure V has anything suitable yet ?!?
   I like python's simplicity. Anything that implements a read() interface, read_buffer() interface will do
   and either allow byte by byte reading, or also returning to position still in the buffer.
- 'find' is currently highly optimized, simply skipping bytes that don't match, until the end of the
  input, ignoring any line-ends. If you want anything else, you need to build it with standard
  pattern. This approach, so far, works well as long as "lines" are provided for matching. Breaking
  text/files into lines, happens outside rosie. I'm wondering whether we could leverage 'dot'
  for 'find'. Users may redefine it in their package, and 'find' works different, e.g. stop at
  line-end; detect utf-8 chars and move the respective number of bytes forward, ...
  To that respect, I'm wondering whether additional rpl meta-data would be useful, e.g.
  meta.line_mode = true / false; and meta.utf8_input = true/false. The difference compared
  to redefining 'dot' would be that it gets applied to all packages (and thus must go before
  any 'import'). line_mode dot = [^\n\r], and not utf8_input dot = [:ascii:], and [[:ascii:][^\n\r]]
  An alternative would be function parameters, which are not yet supported.
- I tested 'str' and 'test_str' instructions, but it was overall slower. I'm not sure, but may be this is
  an effect of instruction cache and other buffers, or "optimization work best in small function".
  I need to re-do it, and use a different str.len when to start using str vs char. And put it into
  a function may be.
- lines: My gut feeling is that Rosie cli, 'grep', ... split into line ahead and outside of the matching
  process. The respective patterns don't seem to do this. I think we need better support for
  line based inputs. Please see a separate todo/note in the cli module
- I need to learn more about "modern CPU performance tuning" to better understand how to tune
  especially the VM runtime.
- There are discussions about stopwatch being a little slow.
  https://discord.com/channels/592103645835821068/592320321995014154/902118300333522974
  Possibly review the benchmark implementation
- https://easyperf.net/ seems to be a good source for low-level CPU performance analysis

