module compiler_backend_vm

import rosie.runtime_v2 as rt


fn prepare_test(rpl string, name string, debug int) ? rt.Rplx {
    eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
    rplx := parse_and_compile(rpl: rpl, name: name, debug: debug, unit_test: false)?
    if debug > 0 { rplx.disassemble() }
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
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.pos == 0

    line = "{a}"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("obj")? == line
    assert m.pos == line.len

    line = "{{a}}"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("obj")? == line
    assert m.pos == line.len

    line = "{{{a}}}"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("obj")? == line
    assert m.pos == line.len
}
/* */
