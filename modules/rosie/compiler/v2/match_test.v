module v2

import rosie.runtimes.v2 as rt


fn prepare_test(rpl string, name string, debug int) ? &rt.Rplx {
	eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
	rplx := parse_and_compile(rpl: rpl, name: name, debug: debug, unit_test: true)?
	if debug > 0 { rplx.disassemble() }
	return rplx
}

fn test_simple_01() ? {
	rplx := prepare_test('{"a"+ "b"}', "*", 0)?
	mut line := "ab"
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "ab"
	assert m.pos == 2

	line = "aab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "aab"
	assert m.pos == 3

	line = "aabc"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "aab"
	assert m.pos == 3

	line = "ac"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = ""
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0
}

fn test_simple_02() ? {
	rplx := prepare_test('{"a"* "b"}', "*", 0)?
	mut line := "ab"
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "ab"
	assert m.pos == 2

	line = "aab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "aab"
	assert m.pos == 3

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "b"
	assert m.pos == 1

	line = ""
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0
}

fn test_simple_03() ? {
	rplx := prepare_test('{"a"{2,4} "b"}', "*", 0)?
	mut line := "aab"
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "aab"
	assert m.pos == 3

	line = "aaab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "aaab"
	assert m.pos == 4

	line = "aaaab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "aaaab"
	assert m.pos == 5

	line = "aaaab1"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "aaaab"
	assert m.pos == 5

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "aaaaab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = ""
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0
}

fn test_simple_04() ? {
	rplx := prepare_test('!"a"', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true     // !pat also matches "no more input"
	assert m.get_match("*")? == ""
	assert m.pos == 0

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == ""   // look-aheads, such as ! == !>, DO NOT consume input
	assert m.pos == 0
}

fn test_simple_05() ? {
	rplx := prepare_test('{"a" .*}', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "a whatever this is"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "ba"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0
}

fn test_simple_06() ? {
	rplx := prepare_test('{.* "a"}', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "whatever this is"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0
}

fn test_simple_07() ? {
	rplx := prepare_test('{{ !"a" . }* "a"}', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == 1

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "a"
	assert m.pos == 1

	line = "aa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "a"
	assert m.pos == 1

	line = "123456 aba"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "123456 a"
	assert m.pos == 8

	line = "whatever this is"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "wha"
	assert m.pos == 3
}

fn test_simple_08() ? {
	rplx := prepare_test('"a" "b"', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "a b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "a bc"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false		// word boundary missing after "a b"
	assert m.pos == 0

	line = "a  \t b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len
}

fn test_simple_08a() ? {
	rplx := prepare_test('find:"a"', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == 1

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "a"
	assert m.pos == 1

	line = "aa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "a"
	assert m.pos == 1

	line = "123456 aba"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "123456 a"
	assert m.pos == 8

	line = "whatever this is"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "wha"
	assert m.pos == 3

	line = "1a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "12a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "123a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "1234a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "12345a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "123456a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "1234567a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "12345678a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "123456789a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "1234567890a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len
}

fn test_simple_16() ? {
	rplx := prepare_test('"a" / "bc"', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "a"
	assert m.pos == 1

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "a"
	assert m.pos == 1

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "bc"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "bc"
	assert m.pos == 2
}

fn test_simple_16a() ? {
	rplx := prepare_test('"bc" / "a"', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "a"
	assert m.pos == 1

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "a"
	assert m.pos == 1

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "bc"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "bc"
	assert m.pos == 2
}

fn test_simple_16b() ? {
	rplx := prepare_test('{"b" "c"} / "a"', "*", 0)?    // Same as 16a
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "a"
	assert m.pos == 1

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "a"
	assert m.pos == 1

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "bc"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "bc"
	assert m.pos == 2
}

fn test_simple_16c() ? {
	rplx := prepare_test('"bc" / "a" / "de"', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "a"
	assert m.pos == 1

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "a"
	assert m.pos == 1

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "bc"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "bc"
	assert m.pos == 2

	line = "de111"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "de"
	assert m.pos == 2
}

fn test_simple_16d() ? {
	rplx := prepare_test('"bc" / [0-9]', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == line.len

	line = "5"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "5"
	assert m.pos == 1

	line = "0a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "0"
	assert m.pos == 1

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "bc"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "bc"
	assert m.pos == 2
}

fn test_simple_16e() ? {
	rplx := prepare_test('[0-9] / "bc"', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == line.len

	line = "5"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "5"
	assert m.pos == 1

	line = "0a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "0"
	assert m.pos == 1

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "bc"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "bc"
	assert m.pos == 2
}

fn test_simple_16f() ? {
	rplx := prepare_test('"bc" / {"a"}', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "a"
	assert m.pos == 1

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "a"
	assert m.pos == 1

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "bc"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "bc"
	assert m.pos == 2
}

fn test_simple_17() ? {
	rplx := prepare_test('{{"a" / "b"} "c"}', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "ac"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "ac"
	assert m.pos == 2

	line = "bc"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "bc"
	assert m.pos == 2

	line = "bcd"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "bc"
	assert m.pos == 2
}

fn test_simple_17b() ? {
	rplx := prepare_test('{{"a" / "b"} "c"}', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "ac"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "bc"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "bcd"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == "bc"
	assert m.pos == 2
}

fn test_simple_17c() ? {
	rplx := prepare_test('("a" / "b") "c"', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "a c"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "b c"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "b cd"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false	// word boundary missing after "b c"
	assert m.pos == 0

	line = "ac"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false

	line = "bc"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
}

fn test_simple_17d() ? {
	rplx := prepare_test('{"a" / "b"} "c"', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "a c"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "b c"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "b cd"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false		// word boundary missing after "b c"
	assert m.pos == 0

	line = "ac"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false

	line = "bc"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
}

fn test_simple_18a() ? {
	rplx := prepare_test('s17 = {{"a" / "b"} "c"}; s18 = {"1" { s17 "d" }}', "s18", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("s18") == false
	assert m.pos == line.len

	line = "1acd"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("s18")? == line
	assert m.get_match("s17")? == "ac"
	assert m.pos == line.len

	line = "1bcd"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("s18")? == line
	assert m.get_match("s17")? == "bc"
	assert m.pos == line.len

	line = "1bcd222"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("s18")? == "1bcd"
	assert m.get_match("s17")? == "bc"
	assert m.pos == 4

	line = "1bc1"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("s18") == false
	assert m.pos == 0
}

fn test_simple_18b() ? {
	rplx := prepare_test('s17 = {{"a" / "b"} "c"}; s18 = "1" { s17 "d" }', "s18", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("s18") == false
	assert m.pos == line.len

	line = "1 acd"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("s18")? == line
	assert m.get_match("s17")? == "ac"
	assert m.pos == line.len

	line = "1 bcd"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("s18")? == line
	assert m.get_match("s17")? == "bc"
	assert m.pos == line.len

	line = "1 bcd222"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false	// word boundary missing after "1 bcd"
	assert m.pos == 0

	line = "1 bc1"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("s18") == false
	assert m.pos == 0
}

fn test_simple_19() ? {
	rplx := prepare_test('{ [[.][a-z]]+ <".com" }', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == line.len

	line = "www.google.com"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "www.google.de"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0
}

fn test_simple_21() ? {
	rplx := prepare_test('import net; find:{ net.any <".com" }', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == line.len

	line = "www.google.com"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len
	//assert m.stats.instr_count == 142
	//assert m.stats.backtrack_len == 8
	//assert m.stats.capture_len == 6
	// assert m.stats.match_time.elapsed().nanoseconds() < 100_000

	// m.captures.print(true)

	line = "www.google.de"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0
	//assert m.stats.instr_count == 910
	//assert m.stats.backtrack_len == 8
	//assert m.stats.capture_len == 62
	//assert m.stats.match_time.elapsed().nanoseconds() < 600_000

	// TODO In case of a mismatch, net.any creates 61 (!?!) Captures
	//m.captures.print(false)
	//assert false
}

fn test_slashed_date() ? {
	rplx := prepare_test('import date; date.us_dashed', "*", 0)?
	mut line := "01-01-77899"
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.pos == 10
}

fn test_escaped_quotes() ? {
	rplx := prepare_test('import word; word.q', "*", 0)?
	mut line := "hello"
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.pos == 0

	line = '"hello"'
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len
/*
	line = r'"\"hello\""'
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == '""hello""'
	assert m.pos == line.len
*/
}

fn test_float() ? {
	rplx := prepare_test('import num; num.float', "*", 0)?
	mut line := "-3.14"
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len
}

fn test_alter_01() ? {
	rplx := prepare_test('a = "a"; b = "b"; c = "c"; e = "1"; obj = {{a b} / {a c} e}', "obj", 0)?
	mut line := "ab1"
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("obj")? == line
	assert m.pos == line.len
}

fn test_and_or() ? {
	rplx := prepare_test('{"a" "b" / "c"}', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "ac"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len
}

fn test_ipv6() ? {
	rplx := prepare_test('import net; net.ipv6', "*", 0)?
	mut line := "::FFFF:129.144.52.38"
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len
}

fn test_re_01() ? {
	rplx := prepare_test('import re; re.btest', "*", 0)?    // TODO obviously we are not yet validating 'public only'
	mut line := "a."
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len
	//eprintln(m.captures)

	line = ".a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len
}

fn test_rpl_fn() ? {
	rplx := prepare_test('import rosie/rpl_1_1 as rpl; rpl.rpl_expression', "*", 0)?
	mut line := "f:(x y)"
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len
	m.print_captures(false)
	// .. requires unit_test = true, so that all bindings are captured
	assert m.get_match("*", "rpl_1_1.exp", "grammar_0.arg")? == "(x y)"
	assert m.get_match("rpl_1_1.exp", "grammar_0.arg")? == "(x y)"
	assert m.get_match("exp", "grammar_0.arg")? == "(x y)"
	assert m.get_match("exp", "grammar_0.arg")? == "(x y)"
	assert m.get_match("exp", "arg")? == "(x y)"
	assert m.get_match("*", "exp", "arg")? == "(x y)"
	assert m.get_match("exp.arg")? == "(x y)"
}

fn test_rpl_fn2() ? {
	rplx := prepare_test('import rosie/rpl_1_1 as rpl; rpl.rpl_expression', "*", 0)?
	mut line := "f:(x, y)"
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len
	//m.print_captures(false)
	assert m.get_match("*", "rpl_1_1.exp", "grammar_0.arglist")? == "(x, y)"
	assert m.get_match("exp", "arglist")? == "(x, y)"
	assert m.get_match("exp.arglist")? == "(x, y)"
}
/* */
