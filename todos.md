- Use 'atmos' to very pseudo function implementation
  - call "atmos"
  - if ret, then proceed after call "sucess"
  - if fail, then proceed after call with "fail"
- "<!(pat)" is equivalent to "!(pat)".  Raise a warning, to inform the user about a possible mistake. They may want
    "!<(pat)" instead
- Jamie's original implementation, always inlines variables.
    - We have a first version of a function call, which was already used for word_boundary (return value yes, parameters no)
      before we provided the word_boundary byte code instruction.
	- from a byte code point of view some "call <addr>" or "invoke <addr>" byte code, and "ret" to return successfully.
	  "Fails" must also return from the function propagating the fail. Implementing this with very good performance
	  has been the challenge so far. The vm() inner-loop is reasonably good, but may be a bit heavy at the intro and exit
	  to be used recursively.
- Research: I wonder whether byte codes, much closer to RPL, provide value. And if it's only for readability
      Not sure for "choice", and also not sure for multiplieres.
      May be for predicates?
      I'm hoping for more optimization options, with higher level byte code instructions, but
      I'm absolutely unclear what that might be.
- to be confirmed: imagine parsing a large html file, or large CSV file. Millions of captures will be created.
    Even the matched captures only will be huge. We need something much more efficient for these use cases:
    E.g. only keep the stack of open parent captures, but remove everything else. (backref won't work anymore).
    In CSV, reading line by line => skipping until newline, might be something useful
    May be a complete streaming approach: the VM keeps just the minimum of capture absolutely needed,
    but publishes (or callback) every capture to the client, so that the user can decided what to do with them.
- V has an [export] attribute to determine the name for C-function names being exported. Relevant for libraries etc.
    May be that could be a way to develop a compliant librosie.so ??
- Using rosie lang gitlab issues; i had good discussions with Jamie on RPL and some features. We definitely should
    try to build some of them into the platform.
    I like Jamie's ideas for rpl 2.0 (see several gitlab issue for the discussions)
    - clarify backref resolution process
    - "&" operator currently translates to {>a b}. Either remove "&" completely or make it an optional "and" operator
	  And it has an undocumented other meaning with [..], e.g. [[ab] & [b]] == [a]. Here is a logical or.
    - tok:(..) instead of (..)
    - or:(..) instead of [..] (but still supporting "/" operator)
    - no more (), {} and []. Only () for untokenized concatenations. [] replaced with or:() and () replaced
      with tok:() macros. [] only for charsets.
    - make grammar syntax like a package, or remove completely and make recursive a modifier of a binding
- Leverage rosie parser/rpl, to parse rpl input (and compare parser performance)
	- should get that working, before starting work on RPLv2 changes
	- May be start with a test: parse all the lib-rpl files and review how many captures are generated
- Research: a compiler backend that generates V-code, rather then VM byte code (and compare performance)
    you can generate .v code, then compile it and run it yourself -
    @VEXE gives you the path to the V executable, so you can do
    os.system('${@VEXE} run generated_code.v')
	May be a first step would be to allow user-provided V-code for user defined byte-codes
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
	But it does a reasonable very basic job of syntax high-lighting. Nothing else though.
- documentation, documentation, documentation, ...
- Some sort of streaming interface for the input data. Not sure V has anything suitable yet ?!?
   I like python's simplicity. Anything that implements a read() interface, read_buffer() interface will do
   and either allow byte by byte reading, or also returning to position still in the buffer.
   This is also necessary for files > 2GB since V []byte cannot be large (.size and .cap are int values)
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
- lines: My gut feeling is that Rosie cli, 'grep', ... split into line ahead and outside of the matching
  process is fast. The respective patterns don't seem to do this. I think we need better support for
  line based inputs. Please see a separate todo/note in the cli module
- until_char: experiment with comparing 2/4/8 bytes at onces, rather then one after the other
  Also see asmlib (C lib) for SIMD optimized string functions (only for C-like strings though).
  May be the C (production) compiler or the std-libs are doing that already?
- I need to learn more about "modern CPU performance tuning" to better understand how to tune
  especially the VM runtime.
   https://easyperf.net/ seems to be a good source for low-level CPU performance analysis
- A little tool to chart the performance trends based on the benchmark logs
- if static arrays are soo much faster, I wonder whether it makes sense to copy 'input' ??
	May only be relevant for longer/larger inputs. We are using fixed size arrays for BTstack
	already, and benchmarks have shown much it is faster.
- Need to work on the "user" interface. The interface that user's of the lib are meant to use.
  This API should be rather stable moving forward. Things behind may still change.
  I'd like to have V-lang user interface, as well as C-lang / external lib user interface.
  May be:
  	rosie := vrosie_init()							// initialize (create a pseudo global variable)
  	file_rpl := vrosie_parse_file(rosie, file)		// read file into AST
  	vrosie_add_to_cache(rosie, file_rpl)			// Add AST to "global" cache
  	parser := vrosie_parse(rosie, pat)				// parse a string vs a file content
  	rplx := vrosie_compile(rosie, parser, name)		// create byte code for a specific pattern
	vrosie_add_rplx_to_cache(rosie, rplx, name)		// Add the byte code to a "global" cache
  	match := vrosie_match(rosie, rplx, input)		// Run a match of the input against the rplx
  	match := vrosie_match_xxx(rosie, rplx, input, fn captures)	// streaming invocation of capture function
  	out := vrosie_replace(rosie, rplx, input, replace)			// Replace the pattern that matched ...
  	out := vrosie_replace_fn(rosie, rplx, input, fn_replace)	// Replace the pattern that matched calling a replace function
	.. methods to review captures ..
	.. convinience functions ..
	match := vrosie_match(rosie, pat, input)		// combine: parse, compile, and match
	rplx := vrosie_compile(rosie, pat)				// combine: parse and compile
- find:{"\n" "\r"?} == find:{"\n"} "\r"? which translates into
	- until_char "\n"
	- any  // "\n"
	- skip_char "\r"
	Can we implement this optimization?
- Once the new rpl-parser is ready, I'd like to play with additional rpl-dialects, e.g.
	- "pub" instead of "local" and "alias": Reason: orig rpl_1_3 really creates an excessive amount of captures.
	    I think that is because non-local non-alias is the default.
	- "recursive xyz = .." instead of grammar
	- only () for grouping. No more {} or [] disjunctions. [] only for charsets, ~ for word-boundary and / for disjunctions
	- end-of-line terminates a pattern, except if grouped by () => Today this is another source of massive amount of captures.
	- support .*? for non-greedy pattern. The parser/compiler should translate it into efficient byte code, without the regex issues
	- no more {p & q} => {>p q}. But [:digit:] & ![0] == [123456789]
	- I'm not sure about right associativity. {a b / c} == {a {b / c}}. vs {{a b} / c}. I think there is no clear winner.
	  They have not pros and cons. I personally find {{a b} / c} more intuitive. The direction I'm reading.
	  May be would should treats it like in maths: "and" has precendence over "or"
	- we need a modifier like "deep_alias" or "hide" or "no_captures" to define *in the RPL* that none of the captures of this binding
	  should be captured. Or may be a macro? no_captures:{..}
- I probably should be using github issues to track things better
- Not sure I like that the core-0 parser has lots and lots of very small arrays (groups of pattern).
  May be an approach with 1x large array, but some "indent" and "group-id" (simple counter) would be better.
  We still need something for the & / operations. One more attribute?
  One of the characterstics is that we only need to move forward, access the last, and move the last
  into the new group.
- I don't think we have enough tests for the cli
- It is V best practice to use one-letter names, e.g. 'fn (e Engine)' vs. 'fn (engine Engine)' => Find & replace
- V has introduced a -show-timings cli option. I like it, and something similar for Rosie would really be nice.
- The current Compiler is only able to generate runtime v2 byte codes.
- Currently a command is 8 bits, and 24 bits auxillary => Slot
  - Does it make a difference to not mix byte code and aux, but rather have them in separate slots?
    Currently isize == 2 for ALL instructions. This change would mean that this is no longer true. We did
	this for performance reasons.
  - Looking at the hex-codes of the generated byte codes, then there are lots of 0x00. Would it be faster
    to have smaller overall byte code? May be because more instructions fit into the CPU cache.
- "{[..]+}?" can be optimized to "[..]*" in rpl 1.3 file
- Add a byte code for quoted strings, e.g. ".." or '..', with and without escape char. Do we need support for
  "must not cross newline", or python style """...""" and similar?
- We need an rpl construct to stop execution, e.g. upon syntax_error
- anon symtypes now working, e.g.
		struct Abc {
			con none | net.TcpConn
		}

		fn main() {
			a := Abc{}
			if a.con is net.TcpConn {
				println('a.con is valid')
			}
			println('done')
		}
- It should not be complicated to create shared libs (.so, .dll) with the rplx byte code embedded,
  and also executables. And since we have multiple entrypoints, you have have libs with all the
  pattern you need.
  - Which brings me again to a V-build system. build.vsh - a V-lang shell script, that runs on
    all OSes, that generates source codes if needed, builds shared libs and executables (e.g. cli),
	container images if needed, etc.. Install the software if needed? may be. Is v.mod meant to be
	the config file for it? Currently it is not.
- How to test output?
		import os
		const vexe = os.getenv('VEXE')
		const myfolder = os.dir(@FILE)
		fn test_my_cli_program() ? {
			os.chdir(myfolder)?
			res := os.execute('"$vexe" run your_cli_program.v')
			assert res.exit_code == 0
			assert res.output.contains('expected_output')
		}
