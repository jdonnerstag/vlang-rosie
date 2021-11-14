module rpl

import os
import rosie.compiler_vm_backend as compiler
import rosie.runtime_v2 as rt

fn prepare_test(rpl string, name string, debug int) ? rt.Rplx {
	//eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
	rplx := compiler.parse_and_compile(rpl: rpl, name: name, debug: debug, unit_test: false)?
	if debug > 0 { rplx.disassemble() }
	return rplx
}

fn test_preparse() ? {
	// Use the core-0 parser to determine the number of captures when parsing
	// the lib rpl files
	rpl := os.read_file('./rpl/rosie/rpl_1_3.rpl')?
	rplx := prepare_test(rpl, "preparse", 0)?
	mut line := os.read_file("./rpl/date.rpl")?		// with rpl statement
	mut m := rt.new_match(rplx, 0)
	assert m.vm_match(line) == true
	str := m.get_match_by("preparse")?.trim_space()
	assert str.ends_with("rpl 1.1")
	assert m.pos == 384
	assert m.captures.len == 386
	//m.print_captures(false)

	line = os.read_file("./rpl/all.rpl")?		// without rpl statement
	m = rt.new_match(rplx, 0)
	assert m.vm_match(line) == false
	assert m.pos == 0
	assert m.captures.len == 303
}

fn test_statement() ? {
	// Use the core-0 parser to determine the number of captures when parsing
	// the lib rpl files
	rpl := os.read_file('./rpl/rosie/rpl_1_3.rpl')?
	rplx_preparse := prepare_test(rpl, "preparse", 0)?
	mut line := os.read_file("./rpl/date.rpl")?		// with rpl statement
	mut m := rt.new_match(rplx_preparse, 0)
	assert m.vm_match(line) == true
	assert m.pos == 384
	mut start_pos := m.pos
	rplx_stmt := prepare_test(rpl, "rpl_statements", 0)?
	m = rt.new_match(rplx_stmt, 0)
	m.input = line
	assert m.vm(0, start_pos) == true
	assert m.pos == line.len
	assert m.captures.len == 19240
	//m.print_captures(true)

	line = os.read_file("./rpl/all.rpl")?		// without rpl statement
	m = rt.new_match(rplx_preparse, 0)
	assert m.vm_match(line) == false
	assert m.pos == 0
	assert m.captures.len == 303
	start_pos = m.pos
	m = rt.new_match(rplx_stmt, 0)
	m.input = line
	assert m.vm(0, start_pos) == true
	assert m.pos == line.len
	assert m.captures.len == 5453
	m.print_captures(true)
}