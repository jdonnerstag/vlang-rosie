module rpl


import os
import rosie
import rosie.runtime_v2 as rt
import rosie.compiler_vm_backend as compiler

struct Parser {
pub:
	rplx_preparse rt.Rplx
	rplx_stmts rt.Rplx

	debug int
	import_path []string

pub mut:
	package_cache &PackageCache
	package string		// The current variable context
	grammar string		// Set if anywhere between 'grammar' .. 'end'

	parents []Pattern
	recursions []string		// Detect recursions
}

pub fn init_libpath() ? []string {
	rosie := rosie.init_rosie()?
	return rosie.libpath
}

[params]	// TODO A little sad that V-lang requires this hint, rather then the language being properly designed
pub struct ParserOptions {
	package string = "main"
	debug int
	package_cache &PackageCache = &PackageCache{}
}

pub fn new_parser(args ParserOptions) ?Parser {
	rpl := os.read_file('./rpl/rosie/rpl_1_3.rpl')?
	rplx_preparse := compiler.parse_and_compile(rpl: rpl, name: "preparse")?
	rplx_stmts := compiler.parse_and_compile(rpl: rpl, name: "rpl_statements")?

	mut parser := Parser {
		rplx_preparse: rplx_preparse
		rplx_stmts: rplx_stmts
		debug: args.debug
		package_cache: args.package_cache
		package: args.package
		import_path: init_libpath()?
	}

	parser.package_cache.add_package(name: args.package, fpath: args.package)?

	// Add builtin package, if not already present
	parser.package_cache.add_builtin()

	return parser
}

pub fn (mut parser Parser) parse() ? {
	// todo
}
