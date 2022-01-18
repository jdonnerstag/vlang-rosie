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
	assert m.vm_match(line)? == false			// We stopped because of halt. The halt child pattern failed => return value == false
	//m.print_captures(true)
	assert m.halted() == true
	if _ := m.get_halt_match() { assert false }	// 'halt' itself does not capture anything. Instead get_halt_match() returns the first capture following.
	if _ := m.get_match("*") { assert false }	// Did not yet reach main.* close_capture.
	assert m.pos == 0

	assert m.vm_continue(false)? == false		// "" does not match => main.* == false
	//m.print_captures(true)
	assert m.halted() == false					// Finished processing the input
	assert m.pos == 0


	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true			// We stopped because of halt. The halt child pattern matched => true
	//m.print_captures(true)
	assert m.halted() == true					// We 'halted'
	assert m.get_halt_match()? == "a"			// The halt child pattern matched
	assert m.get_halt_symbol()? == "_halt_"		// We inserted an additional capture, to capture the halt child pattern
	if _ := m.get_match("*") { assert false }	// We 'halted', so we did not reach the main.* close capture yet
	assert m.pos == 1

	assert m.vm_continue(false)? == true		// Reached end of input and matched => true
	//m.print_captures(true)
	assert m.halted() == false					// End of input; not a halt
	assert m.get_match("*")? == line
	assert m.pos == line.len


	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false			// We stopped because of halt. The halt child pattern did not matched => false
	//m.print_captures(true)
	assert m.halted() == true					// We 'halted'
	if _ := m.get_halt_match() { assert false }	// The halt child pattern did not match
	if _ := m.get_match("*") { assert false }	// We 'halted', so we did not reach the main.* close capture yet
	assert m.pos == 0

	assert m.vm_continue(false)? == false		// reached the end. But main.* did not match => false
	//m.print_captures(true)
	assert m.halted() == false					// End of input; not a halt
	if _ := m.get_match("*") { assert false }	// main.* did not match
	assert m.pos == 0
}

fn test_identifier() ? {
	// Do not insert _halt_, but rather user the 'aaa' capture
	mut rplx := prepare_test('aaa = "a"; halt:aaa', "*", 0)?

	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false			// We stopped because of halt. The halt child pattern failed => return value == false
	//m.print_captures(true)
	assert m.halted() == true
	if _ := m.get_halt_match() { assert false }	// 'halt' itself does not capture anything. Instead get_halt_match() returns the first capture following.
	if _ := m.get_match("*") { assert false }	// Did not yet reach main.* close_capture.
	assert m.pos == 0

	assert m.vm_continue(false)? == false		// "" does not match => main.* == false
	//m.print_captures(true)
	assert m.halted() == false					// Finished processing the input
	assert m.pos == 0


	line = "a"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true			// We stopped because of halt. The halt child pattern matched => true
	//m.print_captures(true)
	assert m.halted() == true					// We 'halted'
	assert m.get_halt_match()? == "a"			// The halt child pattern matched
	assert m.get_halt_symbol()? == "main.aaa"	// We inserted an additional capture, to capture the halt child pattern
	if _ := m.get_match("*") { assert false }	// We 'halted', so we did not reach the main.* close capture yet
	assert m.pos == 1

	assert m.vm_continue(false)? == true		// Reached end of input and matched => true
	//m.print_captures(true)
	assert m.halted() == false					// End of input; not a halt
	assert m.get_match("*")? == line
	assert m.pos == line.len


	line = "b"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == false			// We stopped because of halt. The halt child pattern did not matched => false
	//m.print_captures(true)
	assert m.halted() == true					// We 'halted'
	if _ := m.get_halt_match() { assert false }	// The halt child pattern did not match
	if _ := m.get_match("*") { assert false }	// We 'halted', so we did not reach the main.* close capture yet
	assert m.pos == 0

	assert m.vm_continue(false)? == false		// reached the end. But main.* did not match => false
	//m.print_captures(true)
	assert m.halted() == false					// End of input; not a halt
	if _ := m.get_match("*") { assert false }	// main.* did not match
	assert m.pos == 0
}

fn test_rpl() ? {
	rplx := prepare_test(r'ws=[ \n\r]; rpl={"rpl" " "+ [:digit:] "." [:digit:]}; main = {ws* halt:{rpl?} .*}', "main", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true		// halted: captured rpl?
	//m.print_captures(true)
	assert m.halted() == true
	assert m.get_halt_match()? == ""
	if _ := m.get_match("main") { assert false }
	assert m.pos == 0

	assert m.vm_continue(false)? == true		// reached the end
	//m.print_captures(true)
	assert m.halted() == false					// End of input; not a halt
	assert m.get_match("main")? == ""
	assert m.pos == 0


	line = 'test = "xxx"'
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true		// halted: captured rpl?
	//m.print_captures(true)
	assert m.halted() == true
	assert m.get_halt_match()? == ""
	if _ := m.get_match("main") { assert false }
	assert m.pos == 0

	assert m.vm_continue(false)? == true		// reached the end
	//m.print_captures(true)
	assert m.halted() == false					// End of input; not a halt
	assert m.get_match("main")? == line
	assert m.pos == line.len


	line = "rpl 1.3"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true		// halted: captured rpl?
	//m.print_captures(true)
	assert m.halted() == true
	assert m.get_halt_match()? == line
	if _ := m.get_match("main") { assert false }
	assert m.pos == line.len

	assert m.vm_continue(false)? == true		// reached the end
	//m.print_captures(true)
	assert m.halted() == false					// End of input; not a halt
	assert m.get_match("main")? == line
	assert m.pos == line.len


	line = '              rpl 1.3; test="xxx"'
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true		// halted: captured rpl?
	//m.print_captures(true)
	assert m.halted() == true
	assert m.get_halt_match()? == "rpl 1.3"
	if _ := m.get_match("main") { assert false }
	assert m.pos == 21

	assert m.vm_continue(false)? == true		// reached the end
	//m.print_captures(true)
	assert m.halted() == false					// End of input; not a halt
	assert m.get_match("main")? == line
	assert m.pos == line.len
}
/* */
