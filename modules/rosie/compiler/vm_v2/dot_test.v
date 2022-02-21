module vm_v2

import rosie
import rosie.runtimes.v2 as rt


fn prepare_test(rpl string, name string, debug int) ? &rosie.Rplx {
	eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
	rplx := parse_and_compile(rpl: rpl, name: name, debug: debug, unit_test: false)?
	if debug > 0 { rt.disassemble(rplx) }
	return rplx
}

fn test_single() ? {
	rplx := prepare_test('.', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "a"
	assert m.pos == 1

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "b"
	assert m.pos == 1

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "a"
	assert m.pos == 1

	line = "ba"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "b"
	assert m.pos == 1
}

fn test_0_or_more() ? {
	rplx := prepare_test('.*', "*", 0)?    // This always consumes everything. See Rosie doc
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "aaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "aaab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "baaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len
}

fn test_0_or_1() ? {
	rplx := prepare_test('.?', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "aaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "a"
	assert m.pos == 1

	line = "aaab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "a"
	assert m.pos == 1

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "b"
	assert m.pos == 1

	line = "baaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "b"
	assert m.pos == 1
}

fn test_1_or_more() ? {
	rplx := prepare_test('.+', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "aaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "aaab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "baaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len
}

fn test_n_to_m() ? {
	rplx := prepare_test('.{2,4}', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "aa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "aaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "aaaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "aaaaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "aaaa"
	assert m.pos == 4

	line = "aaab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "aaab"
	assert m.pos == 4

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "baaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "baaa"
	assert m.pos == 4
}

fn test_0_to_m() ? {
	rplx := prepare_test('.{,4}', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "aa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "aaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "aaaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "aaaaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "aaaa"
	assert m.pos == 4

	line = "aaab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "aaab"
	assert m.pos == 4

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "b"
	assert m.pos == 1

	line = "baaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "baaa"
	assert m.pos == 4
}

fn test_n_to_many() ? {
	rplx := prepare_test('.{2,}', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "aa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "aaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "aaaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "aaaaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "aaab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "aaab"
	assert m.pos == 4

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "baaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "baaa"
	assert m.pos == 4
}
