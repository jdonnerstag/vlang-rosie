module compiler_backend_vm

import rosie.runtime_v2 as rt
import rosie.parser

pub struct ParseAndCompileOptions {
	rpl string
	name string
	debug int
	unit_test bool
}

pub fn parse_and_compile(args ParseAndCompileOptions) ? rt.Rplx {
	if args.debug > 0 { eprintln("Parse RPL input") }
	mut p := parser.new_parser(data: args.rpl, debug: args.debug)?
	p.parse()?
	if args.debug > 1 { eprintln(p.binding(args.name)?.repr()) }

	if args.debug > 0 { eprintln("Expand parsed input for binding: '$args.name'") }
	p.expand(args.name)?
	if args.debug > 1 { eprintln(p.binding(args.name)?.repr()) }

	if args.debug > 0 { eprintln("Compile pattern for binding: '$args.name'") }
	mut c := new_compiler(p, args.unit_test, args.debug)
	c.compile(args.name)?

    rplx := rt.Rplx{ symbols: c.symbols, code: c.code }
	return rplx
}
