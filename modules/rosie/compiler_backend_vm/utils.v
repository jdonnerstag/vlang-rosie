module compiler_backend_vm

import rosie.runtime_v2 as rt
import rosie.parser

struct ParseAndCompileOptions {
	rpl string
	name string
	debug int
	unit_test bool
}

pub fn parse_and_compile(args ParseAndCompileOptions) ? rt.Rplx {
	mut p := parser.new_parser(data: args.rpl, debug: args.debug)?
	p.parse()?
	//if debug > 0 { eprintln(p.package.bindings) }

	p.expand(args.name)?
	//if debug > 0 { eprintln(p.package.bindings) }

	if args.debug > 1 { eprintln("Run compiler for '$args.name'") }
	mut c := new_compiler(p, args.unit_test, args.debug)
	c.compile(args.name)?

    rplx := rt.Rplx{ symbols: c.symbols, code: c.code }
	return rplx
}
