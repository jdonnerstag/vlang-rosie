module compiler

import rosie.runtime_v2 as rt
import rosie.parser.core_0 as parser

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
	mut c := new_compiler(p, unit_test: args.unit_test, debug: args.debug)
	c.user_captures = args.captures
	c.compile(args.name)?

	return c.rplx
}
