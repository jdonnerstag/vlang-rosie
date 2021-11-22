module compiler_vm_backend

import rosie.parser.core_0 as parser

pub fn prepare_test(rpl string, debug int) ? Compiler {
	eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")

	if debug > 0 { eprintln("Parse RPL input") }
	mut p := parser.new_parser(debug: debug)?
	p.parse(data: rpl)?

	return new_compiler(p, false, debug)
}

fn test_01() ? {
	mut c := prepare_test('"a"', 0)?

	c.parser.expand("*")?
	c.compile("*")?
	assert c.rplx.entrypoints.find("*")? == 0 	// start_pc == 0
}

fn test_02() ? {
	mut c := prepare_test('a = "a"; b = "b"', 0)?

	c.parser.expand("a")?
	c.compile("a")?

	c.parser.expand("b")?
	c.compile("b")?

	assert c.rplx.entrypoints.find("a")? == 0 	// start_pc == 0
	assert c.rplx.entrypoints.find("b")? == 8

	c.rplx.disassemble()
}
