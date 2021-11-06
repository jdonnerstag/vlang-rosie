module rpl

import os
import rosie.runtime_v2 as rt


fn test_new_parser() ? {
	p := new_parser()?
}

fn test_new_parser_with_date_file() ? {
	// Create a parser by parsing and compiling the rpl_1_3.rpl file
	p := new_parser()?

	// Test the parser against the date.rpl file
	line := os.read_file("./rpl/date.rpl")?

	mut m := rt.new_match(p.rplx_preparse, 0)
	assert m.vm_match(line) == true
	assert m.pos == 384
	//m.print_captures(true)

	start_pos := m.pos
	m = rt.new_match(p.rplx_stmts, 0)
	m.input = line
	assert m.vm(0, start_pos) == true
	assert m.pos == line.len
	assert m.captures.len == 19240
	//m.print_captures(true)
}