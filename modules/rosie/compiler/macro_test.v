module compiler

import rosie.runtime_v2 as rt


fn prepare_test(rpl string, name string, debug int) ? rt.Rplx {
	eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
	rplx := parse_and_compile(rpl: rpl, name: name, debug: debug, unit_test: false)?
	if debug > 0 { rplx.disassemble() }
	return rplx
}

fn test_find_char() ? {
	rplx := prepare_test('find:"a"', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match_by("*") { assert false }
	assert m.pos == 0

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == "a"
	assert m.get_match_by("*", "find:*")? == "a"
	assert m.pos == 1

	line = "aaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == "a"
	assert m.find_cap("main.*", false)?.start_pos == 0
	assert m.find_cap("main.*", false)?.end_pos == 1
	assert m.get_match_by("find:*")? == "a"
	assert m.pos == 1

	line = "bbba"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == "bbba"
	assert m.find_cap("main.*", false)?.start_pos == 0
	assert m.find_cap("main.*", false)?.end_pos == 4
	assert m.get_match_by("find:*")? == "a"
	assert m.pos == line.len
}

fn test_find_string() ? {
	rplx := prepare_test('find:"help"', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match_by("*") { assert false }
	assert m.pos == 0

	line = "help"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == "help"
	assert m.get_match_by("*", "find:*")? == "help"
	assert m.pos == 4

	line = "test this help me"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == "test this help"
	assert m.find_cap("main.*", false)?.start_pos == 0
	assert m.find_cap("main.*", false)?.end_pos == 14
	assert m.get_match_by("find:*")? == "help"
	assert m.pos == 14
}

fn test_find_pattern() ? {
	rplx := prepare_test('find:{"c" [:alnum:]+ <"i"}', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match_by("*") { assert false }
	assert m.pos == 0

	line = "cli"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == "cli"
	assert m.get_match_by("*", "find:*")? == "cli"
	assert m.pos == 3

	line = "test change cli something"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == "test change cli"
	assert m.find_cap("main.*", false)?.start_pos == 0
	assert m.find_cap("main.*", false)?.end_pos == 15
	assert m.get_match_by("find:*")? == "cli"
	assert m.pos == 15

	line = "test change cli something ccc cllli xxx"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == "test change cli"
	assert m.find_cap("main.*", false)?.start_pos == 0
	assert m.find_cap("main.*", false)?.end_pos == 15
	assert m.get_match_by("find:*")? == "cli"
	assert m.pos == 15
}

fn test_find_ci_char() ? {
	rplx := prepare_test('find:ci:"a"', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match_by("*") { assert false }
	assert m.pos == 0

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == line
	assert m.pos == line.len

	line = "A"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == line
	assert m.pos == line.len

	line = "aaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == "a"
	assert m.pos == 1

	line = "bbba"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == "bbba"
	assert m.find_cap("main.*", false)?.start_pos == 0
	assert m.find_cap("main.*", false)?.end_pos == 4
	assert m.pos == line.len

	line = "BbBa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == "BbBa"
	assert m.find_cap("main.*", false)?.start_pos == 0
	assert m.find_cap("main.*", false)?.end_pos == 4
	assert m.pos == line.len
}

fn test_find_ci_string() ? {
	rplx := prepare_test('find:ci:"ab"', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match_by("*") { assert false }
	assert m.pos == 0

	line = "123ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == "123ab"
	assert m.pos == 5

	line = "123Ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == "123Ab"
	assert m.pos == 5
}

fn test_find_ci_charset() ? {
	rplx := prepare_test('find:ci:[a]', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match_by("*") { assert false }
	assert m.pos == 0

	line = "123a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == "123a"
	assert m.pos == 4

	line = "123Ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == "123A"
	assert m.pos == 4

	line = "1234"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match_by("*") { assert false }
	assert m.pos == 0
}

fn test_keepto() ? {
	rplx := prepare_test('keepto:"a"', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match_by("*") { assert false }
	assert m.pos == 0

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == "a"
	assert m.get_match_by("*", "find:<search>")? == ""
	assert m.get_match_by("*", "find:*")? == "a"
	assert m.pos == 1

	line = "aaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == "a"
	assert m.find_cap("main.*", false)?.start_pos == 0
	assert m.find_cap("main.*", false)?.end_pos == 1
	assert m.get_match_by("*", "find:<search>")? == ""
	assert m.get_match_by("find:*")? == "a"
	assert m.pos == 1

	line = "bbba"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == "bbba"
	assert m.find_cap("main.*", false)?.start_pos == 0
	assert m.find_cap("main.*", false)?.end_pos == 4
	assert m.get_match_by("*", "find:<search>")? == "bbb"
	assert m.get_match_by("find:*")? == "a"
	assert m.pos == line.len
}

fn test_findall() ? {
	rplx := prepare_test('findall:"a"', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match_by("*") { assert false }
	assert m.pos == 0

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == "a"
	assert m.get_match_by("*", "find:*")? == "a"
	assert m.pos == 1

	line = "aaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == "aaa"
	assert m.find_cap("main.*", false)?.start_pos == 0
	assert m.find_cap("main.*", false)?.end_pos == 3
	assert m.get_all_match_by("find:*")? == ["a", "a", "a"]
	assert m.pos == line.len

	line = "bbba"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == "bbba"
	assert m.find_cap("main.*", false)?.start_pos == 0
	assert m.find_cap("main.*", false)?.end_pos == 4
	assert m.get_all_match_by("find:*")? == ["a"]
	assert m.pos == line.len

	line = "bbba cca"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == "bbba cca"
	assert m.find_cap("main.*", false)?.start_pos == 0
	assert m.find_cap("main.*", false)?.end_pos == 8
	assert m.get_all_match_by("find:*")? == ["a", "a"]
	assert m.pos == line.len
}

fn test_backref() ? {
	rplx := prepare_test('
		delimiter = [+/|]

		grammar
			balanced = { delimiter balanced backref:delimiter } / ""
		end', "balanced", 0)?

	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("balanced")? == line
	assert m.pos == line.len

	line = "++"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("balanced")? == line
	assert m.get_match_by("delimiter")? == "+"
	assert m.pos == line.len

	line = "a+"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true             // Note: The result is true, because of "" matching everything, the 'balanced' is empty.
	assert m.get_match_by("balanced")? == ""
	assert m.pos == 0

	line = "+||+"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("balanced")? == line
	assert m.get_match_by("delimiter")? == "+"
	assert m.get_match_by("balanced", "delimiter")? == "+"
	assert m.get_match_by("balanced", "balanced", "delimiter")? == "|"  // note: you can follow the match path to find the 2nd delimiter
	assert m.pos == line.len

	line = "+|/+"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("balanced")? == ""
	assert m.pos == 0
}

fn test_onetag() ? {
	rplx := prepare_test('import ../test/backref-rpl as bref; x = bref.onetag', "x", 11)?

	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false

	line = "<foo></foo>"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("x")? == line
	assert m.pos == line.len

	line = "<foo> blah blah b</foo>"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("x")? == line
	assert m.get_match_by("x")? == line
	assert m.pos == line.len

	line = "<foo> blah blah b</foo2>"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
}

fn test_nested_html() ? {
	rplx := prepare_test('import ../test/backref-rpl as bref; x = bref.html', "x", 0)?

	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false

	line = "<foo><bar></bar></foo>"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("x")? == line
	assert m.pos == line.len

	line = "<foo></foo><bar></bar>"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("x")? == line
	assert m.pos == line.len
}

fn test_find_last() ? {
	rplx := prepare_test('find:{<"com"}', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match_by("*") { assert false }
	assert m.pos == 0

	line = "com"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == line
	assert m.get_match_by("*", "find:*")? == ""
	assert m.pos == line.len

	line = "bla.bla.com"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == line
	assert m.get_match_by("*", "find:*")? == ""
	assert m.pos == line.len
}

fn test_find_not() ? {
	rplx := prepare_test('find:{!"1"}', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == ""
	assert m.pos == 0

	line = "com"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == ""
	assert m.pos == 0

	line = "111112"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == "11111"
	assert m.pos == 5
}
/* */