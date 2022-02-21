module vm_v2

import rosie
import rosie.runtimes.v2 as rt


fn prepare_test(rpl string, name string, debug int) ? &rosie.Rplx {
	eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
	rplx := parse_and_compile(rpl: rpl, name: name, debug: debug, unit_test: false)?
	if debug > 0 { rt.disassemble(rplx) }
	return rplx
}

const grammar_rpl = '
grammar
	aa = "a" / obj
in
	obj = { "{" aa "}" }
end
'

fn test_grammar() ? {
	rplx := prepare_test(grammar_rpl, "obj", 0)?
	mut line := ""
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == false
	assert m.pos == 0

	line = "{a}"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("obj")? == line
	assert m.pos == line.len

	line = "{{a}}"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("obj")? == line
	assert m.pos == line.len

	line = "{{{a}}}"
	m = rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(input: line)? == true
	assert m.get_match("obj")? == line
	assert m.pos == line.len
}
/* */
