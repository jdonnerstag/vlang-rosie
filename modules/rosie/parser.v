module rosie

// TODO not yet used ?!?! See core_0 parser
[params]
pub struct ParserOptions {
pub:
	file string					// If Rpl comes from a file ... (e.g. 'import' statments)
	data string	    			// If Rpl is provided directly (source code, command line, ..)
	package string				// TODO remove ??
	module_mode bool			// Mainly for test purposes. If true, treat data as if read from file	// TODO remove if possible
}

// Note: So far this is a very thin interface build around the compiler requirements.
interface Parser {
	// parse Parse the user provided pattern. Every parser has an associated package
	// which receives the parsed statements. An RPL "import" statement will leverage
	// a new parser rosie. Packages are shared by the parsers.
	//parse(args ParserOptions) ?  // Not relevant for the parser

	binding(name string) ? &Binding

mut:
	parse(args ParserOptions) ?

	expand(varname string) ? Pattern	// This seems mostly for tests, and not neeeded by the compiler

	main &Package						// The package that will receive the bindings being parsed.
	current &Package					// Set if parser is anywhere between 'grammar' and 'end'
}