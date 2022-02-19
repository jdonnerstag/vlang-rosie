module vm_v2

import rosie.parser.stage_0 as parser
import rosie.runtimes.v2 as rt


pub fn prepare_test(rpl string, debug int) ? Compiler {
	eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")

	if debug > 0 { eprintln("Parse RPL input") }
	mut p := parser.new_parser(debug: debug)?
	p.parse(data: rpl)?

	return new_compiler(p.main, unit_test: false, debug: debug)
}

fn test_01() ? {
	mut c := prepare_test('"a"', 0)?
	c.compile("*")?
	assert c.rplx.entrypoints.find("*")? == 0 	// start_pc == 0
}

fn test_02() ? {
	mut c := prepare_test('a = "a"; b = "b"', 0)?
	c.compile("a")?
	c.compile("b")?

	assert c.rplx.entrypoints.find("a")? == 0 	// start_pc == 0
	assert c.rplx.entrypoints.find("b")? == 8

	c.rplx.disassemble()
}

fn test_single() ? {
	mut c := prepare_test('"a"', 0)?
	c.compile("*")?

	mut line := ""
	mut m := rt.new_match(rplx: c.rplx, debug: 0)
	assert m.vm_match(input: line, entrypoint: "*")? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "a"
	m = rt.new_match(rplx: c.rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "a"
	assert m.pos == 1

	m = rt.new_match(rplx: c.rplx, debug: 0)
	assert m.vm_match(input: line, entrypoint: "*")? == true
	assert m.get_match("*")? == "a"
	assert m.pos == 1
}

fn test_single_multiple() ? {
	mut c := prepare_test('a = "a"; b = "b"', 0)?
	c.compile("a")?
	c.compile("b")?

	mut line := ""
	mut m := rt.new_match(rplx: c.rplx, debug: 0)
	assert m.vm_match(input: line, entrypoint: "a")? == false
	if _ := m.get_match("a") { assert false }
	assert m.pos == 0

	line = "a"
	m = rt.new_match(rplx: c.rplx, debug: 0)
	assert m.vm_match(input: line, entrypoint: "a")? == true
	assert m.get_match("a")? == "a"
	assert m.pos == 1

	m = rt.new_match(rplx: c.rplx, debug: 0)
	assert m.vm_match(input: line, entrypoint: "b")? == false

	line = "b"
	m = rt.new_match(rplx: c.rplx, debug: 0)
	assert m.vm_match(input: line, entrypoint: "b")? == true
	assert m.get_match("b")? == "b"
	assert m.pos == 1

	m = rt.new_match(rplx: c.rplx, debug: 0)
	assert m.vm_match(input: line, entrypoint: "a")? == false
}
