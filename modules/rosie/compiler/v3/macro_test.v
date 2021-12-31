module v3

import rosie.runtimes.v3 as rt


fn prepare_test(rpl string, name string, debug int) ? &rt.Rplx {
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
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "a"
	assert m.get_match("*", "find:*")? == "a"
	assert m.pos == 1

	line = "aaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "a"
	assert m.find_cap("main.*", false)?.start_pos == 0
	assert m.find_cap("main.*", false)?.end_pos == 1
	assert m.get_match("find:*")? == "a"
	assert m.pos == 1

	line = "bbba"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "bbba"
	assert m.find_cap("main.*", false)?.start_pos == 0
	assert m.find_cap("main.*", false)?.end_pos == 4
	assert m.get_match("find:*")? == "a"
	assert m.pos == line.len
}

fn test_find_string() ? {
	rplx := prepare_test('find:"help"', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "help"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "help"
	assert m.get_match("*", "find:*")? == "help"
	assert m.pos == 4

	line = "test this help me"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "test this help"
	assert m.find_cap("main.*", false)?.start_pos == 0
	assert m.find_cap("main.*", false)?.end_pos == 14
	assert m.get_match("find:*")? == "help"
	assert m.pos == 14
}

fn test_find_pattern() ? {
	rplx := prepare_test('find:{"c" [:alnum:]+ <"i"}', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "cli"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "cli"
	assert m.get_match("*", "find:*")? == "cli"
	assert m.pos == 3

	line = "test change cli something"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "test change cli"
	assert m.find_cap("main.*", false)?.start_pos == 0
	assert m.find_cap("main.*", false)?.end_pos == 15
	assert m.get_match("find:*")? == "cli"
	assert m.pos == 15

	line = "test change cli something ccc cllli xxx"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "test change cli"
	assert m.find_cap("main.*", false)?.start_pos == 0
	assert m.find_cap("main.*", false)?.end_pos == 15
	assert m.get_match("find:*")? == "cli"
	assert m.pos == 15
}

fn test_find_ci_char() ? {
	rplx := prepare_test('find:ci:"a"', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "A"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "aaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "a"
	assert m.pos == 1

	line = "bbba"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "bbba"
	assert m.find_cap("main.*", false)?.start_pos == 0
	assert m.find_cap("main.*", false)?.end_pos == 4
	assert m.pos == line.len

	line = "BbBa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "BbBa"
	assert m.find_cap("main.*", false)?.start_pos == 0
	assert m.find_cap("main.*", false)?.end_pos == 4
	assert m.pos == line.len
}

fn test_find_ci_string() ? {
	rplx := prepare_test('find:ci:"ab"', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "123ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "123ab"
	assert m.pos == 5

	line = "123Ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "123Ab"
	assert m.pos == 5
}

fn test_find_ci_charset() ? {
	rplx := prepare_test('find:ci:[a]', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "123a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "123a"
	assert m.pos == 4

	line = "123Ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "123A"
	assert m.pos == 4

	line = "1234"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0
}

fn test_keepto() ? {
	rplx := prepare_test('keepto:"a"', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "a"
	assert m.get_match("*", "find:<search>")? == ""
	assert m.get_match("*", "find:*")? == "a"
	assert m.pos == 1

	line = "aaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "a"
	assert m.find_cap("main.*", false)?.start_pos == 0
	assert m.find_cap("main.*", false)?.end_pos == 1
	assert m.get_match("*", "find:<search>")? == ""
	assert m.get_match("find:*")? == "a"
	assert m.pos == 1

	line = "bbba"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "bbba"
	assert m.find_cap("main.*", false)?.start_pos == 0
	assert m.find_cap("main.*", false)?.end_pos == 4
	assert m.get_match("*", "find:<search>")? == "bbb"
	assert m.get_match("find:*")? == "a"
	assert m.pos == line.len
}

fn test_findall() ? {
	rplx := prepare_test('findall:"a"', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "a"
	assert m.get_match("*", "find:*")? == "a"
	assert m.pos == 1

	line = "aaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "aaa"
	assert m.find_cap("main.*", false)?.start_pos == 0
	assert m.find_cap("main.*", false)?.end_pos == 3
	assert m.get_all_matches("find:*")? == ["a", "a", "a"]
	assert m.pos == line.len

	line = "bbba"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "bbba"
	assert m.find_cap("main.*", false)?.start_pos == 0
	assert m.find_cap("main.*", false)?.end_pos == 4
	assert m.get_all_matches("find:*")? == ["a"]
	assert m.pos == line.len

	line = "bbba cca"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "bbba cca"
	assert m.find_cap("main.*", false)?.start_pos == 0
	assert m.find_cap("main.*", false)?.end_pos == 8
	assert m.get_all_matches("find:*")? == ["a", "a"]
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
	assert m.get_match("balanced")? == line
	assert m.pos == line.len

	line = "++"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("balanced")? == line
	assert m.get_match("delimiter")? == "+"
	assert m.pos == line.len

	line = "a+"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true             // Note: The result is true, because of "" matching everything, the 'balanced' is empty.
	assert m.get_match("balanced")? == ""
	assert m.pos == 0

	line = "+||+"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("balanced")? == line
	assert m.get_match("delimiter")? == "+"
	assert m.get_match("balanced", "delimiter")? == "+"
	assert m.get_match("balanced", "balanced", "delimiter")? == "|"  // note: you can follow the match path to find the 2nd delimiter
	assert m.pos == line.len

	line = "+|/+"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("balanced")? == ""
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
	assert m.get_match("x")? == line
	assert m.pos == line.len

	line = "<foo> blah blah b</foo>"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("x")? == line
	assert m.get_match("x")? == line
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
	assert m.get_match("x")? == line
	assert m.pos == line.len

	line = "<foo></foo><bar></bar>"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("x")? == line
	assert m.pos == line.len
}

fn test_find_last() ? {
	rplx := prepare_test('find:{<"com"}', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "com"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.get_match("*", "find:*")? == ""
	assert m.pos == line.len

	line = "bla.bla.com"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.get_match("*", "find:*")? == ""
	assert m.pos == line.len
}

fn test_find_not() ? {
	rplx := prepare_test('find:{!"1"}', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == ""
	assert m.pos == 0

	line = "com"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == ""
	assert m.pos == 0

	line = "111112"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "11111"
	assert m.pos == 5
}
/* */
