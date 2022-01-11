module v2

import rosie.runtimes.v2 as rt


fn prepare_test(rpl string, name string, debug int) ? &rt.Rplx {
	eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
	rplx := parse_and_compile(rpl: rpl, name: name, debug: debug, unit_test: false)?
	if debug > 0 { rplx.disassemble() }
	return rplx
}

fn test_simple() ? {
	mut rplx := prepare_test('halt:"a"', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	//m.print_captures(true)
	if _ := m.get_match("*") { assert false }
	if _ := m.get_match("_halt_") { assert false }
	if _ := m.get_halt_match() { assert false }
	assert m.get_halt_symbol()? == "_halt_"
	assert m.pos == 0

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	//m.print_captures(true)
	if _ := m.get_match("*") { assert false }
	assert m.get_match("_halt_")? == "a"
	assert m.get_halt_match()? == "a"
	assert m.get_halt_symbol()? == "_halt_"
	assert m.pos == 1

	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	//m.print_captures(true)
	if _ := m.get_match("*") { assert false }
	if _ := m.get_match("_halt_") { assert false }
	if _ := m.get_halt_match() { assert false }
	assert m.get_halt_symbol()? == "_halt_"
	assert m.pos == 0
}

fn test_rpl() ? {
	rplx := prepare_test(r'ws=[ \n\r]; rpl={"rpl" " "+ [:digit:] "." [:digit:]}; main = {ws* halt:{rpl?} .*}', "main", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	//m.print_captures(true)
	if _ := m.get_match("main") { assert false }
	assert m.get_halt_match()? == ""
	assert m.pos == 0

	line = 'test = "xxx"'
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	//m.print_captures(true)
	if _ := m.get_match("main") { assert false }
	assert m.get_halt_match()? == ""
	assert m.pos == 0

	line = "rpl 1.3"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	//m.print_captures(true)
	if _ := m.get_match("main") { assert false }
	assert m.get_halt_match()? == "rpl 1.3"
	assert m.pos == line.len

	line = '              rpl 1.3; test="xxx"'
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	//m.print_captures(true)
	if _ := m.get_match("main") { assert false }
	assert m.get_halt_match()? == "rpl 1.3"
	assert m.pos == 21

	assert m.vm_continue(false)? == true
	//m.print_captures(true)
	assert m.get_match("main")? == line
	if _ := m.get_halt_match() { assert false }
	assert m.pos == line.len
}
/* */
