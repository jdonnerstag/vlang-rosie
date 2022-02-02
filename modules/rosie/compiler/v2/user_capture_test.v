module v2

import rosie.runtimes.v2 as rt


fn prepare_test(rpl string, name string, debug int, capnames ...string) ? &rt.Rplx {
	eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
	rplx := parse_and_compile(rpl: rpl, name: name, debug: debug, unit_test: false, captures: capnames)?
	if debug > 0 { rplx.disassemble() }
	return rplx
}

fn test_captures() ? {
	pat := 'import net; net.url'
	mut rplx := prepare_test(pat, "*", 0)?
	line := "http://129.144.52.38/test.html"
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len
	assert m.captures.len == 8 // 9

	rplx = prepare_test(pat, "*", 0, "*")?
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len
	assert m.captures.len == 1
}

fn test_frac() ? {
	pat := 'import num; num.any'
	mut rplx := prepare_test(pat, "*", 99)?
	line := "-0.3e+1"
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.get_match("*")? == line
	assert m.pos == line.len
}
/* */