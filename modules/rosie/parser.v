module rosie

// TODO not yet used ?!?! See core_0 parser
[params]
pub struct ParserOptions {
	file string			// If Rpl comes from a file ... (e.g. 'import' statments)
	data string	    	// If Rpl is provided directly (source code, command line, ..)
	module_mode bool	// Mainly for test purposes. If true, treat data as if read from file	// TODO remove if possible
}

interface Parser {
	// parse Parse the user provided pattern. Every parser has an associated package
	// which receives the parsed statements. An RPL "import" statement will leverage
	// a new parser rosie. Packages are shared by the parsers.
	parse(args ParserOptions) ?
}