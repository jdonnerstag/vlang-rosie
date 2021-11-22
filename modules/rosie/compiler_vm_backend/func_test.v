module compiler_vm_backend

import rosie.runtime_v2 as rt


fn prepare_test(rpl string, name string, debug int) ? rt.Rplx {
	eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
	rplx := parse_and_compile(rpl: rpl, name: name, debug: debug, unit_test: false)?
	if debug > 0 { rplx.disassemble() }
	return rplx
}

fn test_01() ? {
	rplx := prepare_test('func alias help = "help"; help', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false

	line = "help"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match_by("*")? == line
	assert m.pos == line.len

	// assert false
}
/* */
