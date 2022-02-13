module rosie

pub const err_rpl_version_not_supported = 1

// TODO not yet used ?!?! See stage_0 parser
[params]
pub struct ParserOptions {
pub:
	file string					// If Rpl comes from a file ... (e.g. 'import' statments)
	data string	    			// If Rpl is provided directly (source code, command line, ..)
	package string				// TODO remove ??
	module_mode bool			// Mainly for test purposes. If true, treat data as if read from file	// TODO remove if possible
	ignore_imports bool 		// Only if true, parse the import files.
}

[params]
pub struct FnExpandOptions {
pub:
	unit_test bool
}

pub struct ImportStmt {
pub:
	alias string
	fpath string
}

// Note: So far this is a very thin interface build around the compiler requirements.
interface Parser {
	binding(name string) ? &Binding

mut:
	parse(args ParserOptions) ?

	main &Package				// The package that will receive the bindings being parsed.
	imports []ImportStmt		// file path of the imports
}
