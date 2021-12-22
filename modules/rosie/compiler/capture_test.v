module compiler

import rosie.runtime_v2 as rt


fn prepare_test(rpl string, name string, debug int) ? &rt.Rplx {
	eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
	rplx := parse_and_compile(rpl: rpl, name: name, debug: debug, unit_test: false)?
	if debug > 0 { rplx.disassemble() }
	return rplx
}

fn test_char() ? {
	rplx := prepare_test('"a" "b"', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	assert m.has_match("*") == false
	assert m.pos == line.len

	line = "a b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "a b"
	assert m.pos == 3

	line = "a b "
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "a b"
	assert m.pos == 3
}

fn test_simple_01() ? {
	rplx := prepare_test('a = "a"; b = "b"; c = a b', "c", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	assert m.has_match("a") == false
	assert m.has_match("b") == false
	assert m.has_match("c") == false
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	assert m.has_match("a") == true
	assert m.get_match("a")? == "a"
	assert m.has_match("b") == false
	assert m.has_match("c") == false
	assert m.pos == 0

	line = "a "
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	assert m.has_match("a") == true
	assert m.get_match("a")? == "a"
	assert m.has_match("b") == false
	assert m.has_match("c") == false
	assert m.pos == 0

	line = "a b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.has_match("a") == true
	assert m.get_match("a")? == "a"
	assert m.has_match("b") == true
	assert m.get_match("b")? == "b"
	assert m.has_match("c") == true
	assert m.get_match("c")? == "a b"
	assert m.pos == 3

	line = "a b c"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.has_match("a") == true
	assert m.get_match("a")? == "a"
	assert m.has_match("b") == true
	assert m.get_match("b")? == "b"
	assert m.has_match("c") == true
	assert m.get_match("c")? == "a b"
	assert m.pos == 3

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	assert m.has_match("a") == true
	assert m.get_match("a")? == "a"
	assert m.has_match("b") == false
	assert m.has_match("c") == false
	assert m.pos == 0
}

fn test_simple_02() ? {
	rplx := prepare_test('a = "a"; b = a "b"; c = b "c"', "c", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	assert m.has_match("a") == false
	assert m.has_match("b") == false
	assert m.has_match("c") == false
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	assert m.has_match("a") == true
	assert m.get_match("a")? == "a"
	assert m.has_match("b") == false
	assert m.has_match("c") == false
	assert m.pos == 0

	line = "a "
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	assert m.has_match("a") == true
	assert m.get_match("a")? == "a"
	assert m.has_match("b") == false
	assert m.has_match("c") == false
	assert m.pos == 0

	line = "a b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	assert m.has_match("a") == true
	assert m.get_match("a")? == "a"
	assert m.has_match("b") == true
	assert m.get_match("b")? == "a b"
	assert m.has_match("c") == false
	assert m.pos == 0

	line = "a b c"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.has_match("a") == true
	assert m.get_match("a")? == "a"
	assert m.has_match("b") == true
	assert m.get_match("b")? == "a b"
	assert m.has_match("c") == true
	assert m.get_match("c")? == "a b c"
	assert m.pos == 5

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	assert m.has_match("a") == true
	assert m.get_match("a")? == "a"
	assert m.has_match("b") == false
	assert m.has_match("c") == false
	assert m.pos == 0
}

fn test_simple_03() ? {
	rplx := prepare_test('a = "a"; b = (a)+;', "b", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	assert m.has_match("a") == false
	assert m.has_match("b") == false
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.has_match("a") == true
	assert m.get_match("a")? == "a"
	assert m.get_match("b")? == "a"
	assert m.pos == 1

	line = "a "
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.has_match("a") == true
	assert m.get_match("a")? == "a"
	assert m.get_match("b")? == "a"
	assert m.pos == 1

	line = "a a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.has_match("a") == true
	assert m.get_match("a")? == "a"
	assert m.get_match("b")? == "a a"
	assert m.pos == 3

	line = "a a a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.has_match("a") == true
	assert m.get_match("a")? == "a"
	assert m.has_match("b") == true
	assert m.get_match("b")? == "a a a"
	assert m.pos == 5
}

fn test_simple_04() ? {
	rplx := prepare_test('a = "a"; b = {a}+;', "b", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	assert m.has_match("a") == false
	assert m.has_match("b") == false
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.has_match("a") == true
	assert m.get_match("a")? == "a"
	assert m.get_match("b")? == "a"
	assert m.pos == 1

	line = "aa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.has_match("a") == true
	assert m.get_match("a")? == "a"
	assert m.get_match("b")? == "aa"
	assert m.pos == 2

	line = "aaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.has_match("a") == true
	assert m.get_match("a")? == "a"
	assert m.get_match("b")? == "aaa"
	assert m.pos == 3

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	assert m.has_match("a") == false
	assert m.has_match("b") == false
	assert m.pos == 0
}

fn test_05() ? {
	rplx := prepare_test('"a"*', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.captures.len == 1
	mut x := m.get_capture_name_idx(0) // TODO see know V bug/issue with assertion not supporting all expressions
	assert x == "main.*"

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.captures.len == 1
	x = m.get_capture_name_idx(0) // TODO see know V bug/issue with assertion not supporting all expressions
	assert x == "main.*"

	line = "aa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.captures.len == 1
	x = m.get_capture_name_idx(0) // TODO see know V bug/issue with assertion not supporting all expressions
	assert x == "main.*"
}

fn test_streaming_capture() ? {
	rplx := prepare_test('a = "a"; b = "b"; c = a b', "c", 0)?
	mut line := "a b"
	mut m := rt.new_match(rplx: rplx, debug: 0)

	// Test that we can count the number of capture
	mut count := 0
	m.fn_cap_ref = &count
	m.cap_notification = fn (idx int, ref voidptr) {
		mut iptr := &int(ref)
		//eprintln("streaming cap: ${*iptr} - $idx")
		(*iptr) ++
	}

	assert m.vm_match(line)? == true
	assert count == 3
	assert m.get_match("a")? == "a"
	assert m.get_match("b")? == "b"
	assert m.get_match("c")? == "a b"
	assert m.pos == 3

	// Test that we can fill an array with the capture (index)
	mut ar := []int{}
	m.fn_cap_ref = &ar	// TODO make fn_cap_ref and cap_notification immutable and configurable upon initialization
	m.cap_notification = fn (idx int, ref voidptr) {
		mut ar := &[]int(ref)
		ar << idx
	}

	assert m.vm_match(line)? == true
	assert ar == [1, 2, 0]
}
/* */
