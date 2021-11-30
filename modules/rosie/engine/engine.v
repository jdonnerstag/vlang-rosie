
module engine

import rosie
import rosie.parser.rpl as parser
import rosie.compiler
import rosie.runtime_v2 as rt


pub struct Engine {
pub:
	debug int

pub mut:
	package_cache 	 rosie.PackageCache
	parser 			 parser.Parser
	// optimizer OptimizerInterface
	// compiler CompilerInterface
	// runtime RuntimeInterface
}

pub struct EngineOptions {
	debug int
}

pub fn new_engine(args EngineOptions) ? Engine {
	return Engine {
		debug: args.debug
		parser: parser.new_parser(debug: 0)?
	}
}

pub fn (mut e Engine) parse(args parser.ParserOptions) ? {
	return e.parser.parse(args)
}

pub fn (e Engine) binding(name string) ? &rosie.Binding {
	return e.parser.binding(name)
}

pub fn (e Engine) pattern(name string) ? &rosie.Pattern {
	return &e.parser.binding(name)?.pattern
}

pub struct ParseAndCompileOptions {
	rpl string
	name string
	debug int
	unit_test bool
	captures []string
}

pub fn parse_and_compile(args ParseAndCompileOptions) ? rt.Rplx {
	if args.debug > 0 { eprintln("Parse RPL input") }
	mut p := parser.new_parser(debug: args.debug)?
	p.parse(data: args.rpl)?
	if args.debug > 1 { eprintln(p.binding(args.name)?.repr()) }

	if args.debug > 0 { eprintln("Expand parsed input for binding: '$args.name'") }
	p.expand(args.name)?
	if args.debug > 1 { eprintln(p.binding(args.name)?.repr()) }

	if args.debug > 0 { eprintln("Compile pattern for binding: '$args.name'") }
	mut c := compiler.new_compiler(p, args.unit_test, args.debug)
	c.user_captures = args.captures
	c.compile(args.name)?

	return c.rplx
}
