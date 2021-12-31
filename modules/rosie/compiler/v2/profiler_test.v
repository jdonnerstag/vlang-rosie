module v2

import rosie.runtimes.v2 as rt


fn prepare_test(rpl string, name string, debug int) ? &rt.Rplx {
	eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
	rplx := parse_and_compile(rpl: rpl, name: name, debug: debug, unit_test: false)?
	if debug > 0 { rplx.disassemble() }
	return rplx
}

fn test_simple_01() ? {
	rplx := prepare_test('"a" "b"', "*", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	rt.print_histogram(m.stats)

	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	rt.print_histogram(m.stats)

	line = "ab"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false
	rt.print_histogram(m.stats)

	line = "a b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	rt.print_histogram(m.stats)

	line = "a bc"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	rt.print_histogram(m.stats)

	line = "a b c"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	rt.print_histogram(m.stats)

	line = "a  \t b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	rt.print_histogram(m.stats)
}

fn test_net_ipv6() ? {
	rplx := prepare_test('import net; net.ipv6', "*", 0)?
	mut line := "::FFFF:129.144.52.38"
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	rt.print_histogram(m.stats)
}

fn test_multiline() ? {
	data := '1111
2222
3333
4444'
	rplx := prepare_test(r'alias d = {[:digit:]+ [\r\n]*}; d', "*", 0)?
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(data)? == true
	assert m.get_match("*")? == "1111\n"
	assert m.pos == 5
	mut count := 1
	for m.pos < m.input.len {
		m.captures.clear()
		m.vm(0, m.pos)
		count += 1
		match count {
			2 {
				assert m.pos == 10
				assert m.get_match("*")? == "2222\n"
			}
			3 {
				assert m.pos == 15
				assert m.get_match("*")? == "3333\n"
			}
			4 {
				assert m.pos == 19
				assert m.get_match("*")? == "4444"
			}
			else { panic("expected max count 4")}
		}
	}
	assert count == 4
}

/* */