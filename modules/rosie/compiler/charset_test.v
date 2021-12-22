module compiler

import rosie.runtime_v2 as rt


fn prepare_test(rpl string, name string, debug int) ? &rt.Rplx {
	eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
	rplx := parse_and_compile(rpl: rpl, name: name, debug: debug, unit_test: false)?
	if debug > 0 { rplx.disassemble() }
	return rplx
}

fn test_single() ? {
	rplx := prepare_test('[:digit:]', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "0"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "0"
	assert m.pos == 1

	line = "1"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "1"
	assert m.pos == 1

	line = "2"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "2"
	assert m.pos == 1

	line = "3"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "3"
	assert m.pos == 1

	line = "4"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "4"
	assert m.pos == 1

	line = "5"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "5"
	assert m.pos == 1

	line = "6"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "6"
	assert m.pos == 1

	line = "7"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "7"
	assert m.pos == 1

	line = "8"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "8"
	assert m.pos == 1

	line = "9"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "9"
	assert m.pos == 1

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "01"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "0"
	assert m.pos == 1

	line = "a1"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0
}

fn test_0_or_more() ? {
	rplx := prepare_test('[:digit:]*', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "0"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "0123456789"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "987b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "987"
	assert m.pos == 3

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == ""
	assert m.pos == 0

	line = "b000"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == ""
	assert m.pos == 0
}

fn test_0_or_1() ? {
	rplx := prepare_test('[:digit:]?', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "0"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "123"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "1"
	assert m.pos == 1

	line = "123b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "1"
	assert m.pos == 1

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == ""
	assert m.pos == 0

	line = "b234"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == ""
	assert m.pos == 0
}

fn test_1_or_more() ? {
	rplx := prepare_test('[:digit:]+', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == line.len

	line = "0"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "0123456789"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "123b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "123"
	assert m.pos == 3

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0

	line = "b123"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	if _ := m.get_match("*") { assert false }
	assert m.pos == 0
}

fn test_n_to_m() ? {
	rplx := prepare_test('[:digit:]{2,4}', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "0"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "01"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "012"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "0123"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "012345"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "0123"
	assert m.pos == 4

	line = "123b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "123"
	assert m.pos == 3

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "b123"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0
}

fn test_0_to_m() ? {
	rplx := prepare_test('[:digit:]{,4}', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "0"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "01"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "012"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "0123"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "01234"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "0123"
	assert m.pos == 4

	line = "123b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "123"
	assert m.pos == 3

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == ""
	assert m.pos == 0

	line = "b123"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == ""
	assert m.pos == 0
}

fn test_n_to_many() ? {
	rplx := prepare_test('[:digit:]{2,}', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "0"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "01"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "012"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "0123"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "01234"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "123b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == "123"
	assert m.pos == 3

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "b123"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0
}

fn test_dquote() ? {
	rplx := prepare_test(r'["]', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = '"'
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len
}

fn test_escape() ? {
	rplx := prepare_test(r'[\\]', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	assert m.has_match("*") == false
	assert m.pos == 0

	line = "\\"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len
}

fn test_negative() ? {
	// This should generate optimized byte code
	rplx := prepare_test(r'[^a]', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
}

fn test_negative_few() ? {
	// [^aA] translates into "not 'a' && not 'b'" which
	rplx := prepare_test(r'[^aA]', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false

	line = "A"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
}

fn test_bit_7() ? {
	rplx := prepare_test(r'[:ascii:]', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "µ"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
}

fn test_cs_plus() ? {
	rplx := prepare_test(r'[a]+', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "aaaa"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
}

fn test_cs_neg_many() ? {
	rplx := prepare_test(r'[^a]*', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "bbbb"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == ""
	assert m.pos == 0
}

fn test_cs_neg_plus() ? {
	rplx := prepare_test(r'[^a]+', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "bbbb"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
}

fn test_dot_charset() ? {
	rplx := prepare_test(r'x = "a"; y = "b"; {{x [[.]]}? y', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false

	line = "a.b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "a."
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false

	line = "a "
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
}
/* */
