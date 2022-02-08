module v2

import rosie.runtimes.v2 as rt


fn prepare_test(rpl string, name string, debug int) ? &rt.Rplx {
	eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
	rplx := parse_and_compile(rpl: rpl, name: name, debug: debug, unit_test: false)?
	if debug > 0 { rplx.disassemble() }
	return rplx
}

fn test_single() ? {
	mut rplx := prepare_test('a = "a"; a', "*", 0)?

	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match("")? == false

	mut line := "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len


	rplx = prepare_test('a = "a"; (a)', "*", 0)?
	line = ""
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match("")? == false

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = " a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "a "
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = " a "
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len


	rplx = prepare_test('a = "a"; {~ a ~}', "*", 0)?
	line = ""
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = " a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "a "
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = " a "
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len
}

fn test_end_token() ? {
	mut rplx := prepare_test('a = "end"; {~ a ~}', "*", 0)?

	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false

	line = "end"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = " end"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len

	line = "end_token"							// "_" is a valid [:punct:]
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
}
/* */