module compiler_backend_vm

import rosie.runtime_v2 as rt


fn prepare_test(rpl string, name string, debug int) ? rt.Rplx {
    eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
    rplx := parse_and_compile(rpl: rpl, name: name, debug: debug, unit_test: false)?
    if debug > 0 { rplx.disassemble() }
	return rplx
}

fn test_dis_1() ? {
    rplx := prepare_test(r'[[:space:] [>] "/>"]+', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false

    line = " "
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line

    line = ">"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line

    line = "/>"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line

    line = " >"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line

    line = " > />"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
}

fn test_dis_not() ? {
    rplx := prepare_test(r'[^ [:space:] [>] "/>"]', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false

    line = "abc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"

    line = " "
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false

    line = ">"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false

    line = "/>"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false

    line = " >"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false

    line = " > />"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
}

fn test_dis_not_multiple() ? {
    rplx := prepare_test(r'[^ [:space:] [>] "/>"]+', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false

    line = "abc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line

    line = " "
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false

    line = ">"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false

    line = "/>"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false

    line = " >"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false

    line = " > />"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
}

fn test_strings() ? {
    rplx := prepare_test(r'{"abc" / "123"}', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false

    line = "abc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line

    line = "123"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line

    line = "abX"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false

    line = "Abc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false

    line = "023"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false

    line = "124"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
}

/* */