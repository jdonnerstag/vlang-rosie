module compiler_backend_vm

import rosie.parser

fn test_new_compiler() ? {
	mut p := parser.new_parser(data: '"test"', debug: 0)?
	p.parse_binding(0)?
	mut c := new_compiler(p)
	c.compile("*")?
}