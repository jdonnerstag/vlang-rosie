module rpl_3_0

import os
import rosie.runtimes.v2 as rt


fn test_new_parser() ? {
	p := new_parser()?
}

fn no_match_count(m rt.Match) int {
	mut unmatched := 0
	for c in m.captures {
		if c.matched == false {
			unmatched ++
		}
	}
	return unmatched
}

fn test_new_parser_with_date_file() ? {
	p := new_parser()?

	// Test the parser against the date.rpl file
	line := os.read_file("./rpl/date.rpl")?

	mut m := rt.new_match(rplx: p.rplx, entrypoint: const_rpl_module, debug: 0)
	assert m.vm_match(line)? == false
	assert m.get_match("syntax_error")? == '{"1" [0-2]} /\r\n'	// RPL 3.0 is not using {..} any longer
	// m.print_captures(true)
}
/*
 * The below files are all in RPL 1.3 syntax and will fail, as the example above
 *
fn test_new_parser_with_date_file_2() ? {
	mut p := new_parser()?

	// Test the parser against the date.rpl file
	p.parse(file: "./rpl/date.rpl")?
	assert p.m.captures.len == 612 // 1754
	assert no_match_count(p.m) == 75	// The smaller the better
	//p.m.print_captures(true)
	//assert false
}

fn test_rpl_net_file() ? {
	mut p := new_parser()?

	// Test the parser against the date.rpl file
	p.parse(file: "./rpl/net.rpl")?
	assert p.m.captures.len == 1750 // 5093
	assert no_match_count(p.m) == 223 // The smaller the better
	//p.m.print_captures(true)
	//assert false
}
/* */