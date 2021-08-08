module compiler_backend_vm

import rosie.runtime as rt
import rosie.parser

fn parse_and_compile(rpl string, name string, debug int) ? rt.Rplx {
	mut p := parser.new_parser(data: rpl, debug: debug)?
	p.parse()?
	mut c := new_compiler(p)
	c.compile(name)?
    rplx := rt.Rplx{ ktable: c.symbols, code: c.code }
	return rplx
}
