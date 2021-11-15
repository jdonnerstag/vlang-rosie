module rpl

import os
import rosie.runtime_v2 as rt


fn test_new_parser() ? {
	p := new_parser()?
}

fn test_new_parser_with_date_file() ? {
	// Create a parser by parsing and compiling the rpl_1_3_jdo.rpl file
	p := new_parser(rpl_type: .rpl_module)?

	// Test the parser against the date.rpl file
	line := os.read_file("./rpl/date.rpl")?

	mut m := rt.new_match(p.rplx, 0)
	assert m.vm_match(line) == true
	assert m.pos == 4536
	//m.print_captures(true)
}

fn test_new_parser_with_date_file_2() ? {
	mut p := new_parser(rpl_type: .rpl_module)?

	// Test the parser against the date.rpl file
	p.parse("./rpl/date.rpl")?
	assert p.m.captures.len == 1738
	//p.m.print_captures(true)
	//assert false
}

fn test_rpl_net_file() ? {
	mut p := new_parser(rpl_type: .rpl_module)?

	// Test the parser against the date.rpl file
	p.parse("./rpl/net.rpl")?
	assert p.m.captures.len == 5112
	//p.m.print_captures(true)
	//assert false
}