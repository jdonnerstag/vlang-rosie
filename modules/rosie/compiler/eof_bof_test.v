module compiler

import rosie.runtimes.v2 as rt


fn prepare_test(rpl string, name string, debug int) ? &rt.Rplx {
	eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
	rplx := parse_and_compile(rpl: rpl, name: name, debug: debug, unit_test: false)?
	if debug > 0 { rplx.disassemble() }
	return rplx
}

fn test_01() ? {
	rplx := prepare_test('{"ab" $}', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "aa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "abc"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0
}

fn test_02() ? {
	rplx := prepare_test('{"ab" $} / [:digit:]+', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "aa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "abc"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "111"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "111"
	assert m.pos == 3

	line = "111 a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "111"
	assert m.pos == 3

	line = "111a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "111"
	assert m.pos == 3
}

fn test_03() ? {
	rplx := prepare_test('("ab" $)', "*", 0)?     // No word-boundary between "ab" and $ !!!
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "aa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "abc"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "ab "        // "ab" + word boundary + end of file
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "ab "
	assert m.pos == 3
}

fn test_bof_01() ? {
	rplx := prepare_test('{^ "ab"}', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0
}

fn test_bof_02() ? {
	rplx := prepare_test('(^ "ab")', "*", 0)?       // No word-boundary between ^ and "ab"
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = " ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true   // ^ + word boundary + "ab"
	assert m.get_match("*")? == line
	assert m.pos == line.len
}
