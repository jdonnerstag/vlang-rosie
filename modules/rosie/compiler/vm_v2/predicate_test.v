module vm_v2

import rosie.runtimes.v2 as rt


fn prepare_test(rpl string, name string, debug int) ? &rt.Rplx {
	eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
	rplx := parse_and_compile(rpl: rpl, name: name, debug: debug, unit_test: false)?
	if debug > 0 { rplx.disassemble() }
	return rplx
}

fn test_string_01() ? {
	rplx := prepare_test('>"ab"', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == ""
	assert m.pos == 0

	line = "aa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "ba"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "abc"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == ""
	assert m.pos == 0
}

fn test_string_02a() ? {
	rplx := prepare_test('{[:alnum:]{2,2} <"ab"}', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "aa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len
}

fn test_string_02() ? {
	rplx := prepare_test('{[:alnum:]* <"ab"}', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "123ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "aaaab cde"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "aaaab"
	assert m.pos == 5

	line = "aaaabcde"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "aa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "ba"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "abc"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0
}

fn test_string_03() ? {
	rplx := prepare_test('{[:alnum:]* !<"ab"}', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "1234ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "aa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "ba"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "abc"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = " 1234"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == ""
	assert m.pos == 0
}

fn test_string_04() ? {
	rplx := prepare_test('<!"ab"', "*", 0)?     // See rpl doc. "<!" is equivalent to "!>" which is the same as "!"
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == ""
	assert m.pos == 0

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "aa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == ""
	assert m.pos == 0

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == ""
	assert m.pos == 0

	line = "ba"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == ""
	assert m.pos == 0

	line = "abc"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0
}

fn test_string_05() ? {
	rplx := prepare_test('!>"ab"', "*", 0)?     // This is the same as "!"
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == ""
	assert m.pos == 0

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "aa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == ""
	assert m.pos == 0

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == ""
	assert m.pos == 0

	line = "ba"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == ""
	assert m.pos == 0

	line = "abc"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0
}

fn test_string_06() ? {
	rplx := prepare_test('>!"ab"', "*", 0)?     // This is also the same as "!"
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == ""
	assert m.pos == 0

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "aa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == ""
	assert m.pos == 0

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == ""
	assert m.pos == 0

	line = "ba"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == ""
	assert m.pos == 0

	line = "abc"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0
}
