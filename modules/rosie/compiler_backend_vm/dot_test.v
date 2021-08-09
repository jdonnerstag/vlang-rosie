module compiler_backend_vm

import rosie.runtime as rt


fn prepare_test(rpl string, name string, debug int) ? rt.Rplx {
    eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
    rplx := parse_and_compile(rpl, name, debug)?
    if debug > 0 { rplx.disassemble() }
	return rplx
}

fn test_single() ? {
    rplx := prepare_test('.', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    if _ := m.get_match_by("*") { assert false }
    assert m.pos == 0

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.pos == 1

    line = "b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "b"
    assert m.pos == 1

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.pos == 1

    line = "ba"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "b"
    assert m.pos == 1
}

fn test_0_or_more() ? {
    rplx := prepare_test('.*', "*", 0)?    // This always consumes everything. Not very useful ;)
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "aaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "aaab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "baaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len
}

fn test_0_or_1() ? {
    rplx := prepare_test('.?', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "aaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.pos == 1

    line = "aaab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.pos == 1

    line = "b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "b"
    assert m.pos == 1

    line = "baaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "b"
    assert m.pos == 1
}

fn test_1_or_more() ? {
    rplx := prepare_test('.+', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    if _ := m.get_match_by("*") { assert false }
    assert m.pos == line.len

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "aaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "aaab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "baaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len
}

fn test_n_to_m() ? {
    rplx := prepare_test('.{2,4}', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0

    line = "aa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "aaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "aaaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "aaaaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "aaaa"
    assert m.pos == 4

    line = "aaab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "aaab"
    assert m.pos == 4

    line = "b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0

    line = "baaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "baaa"
    assert m.pos == 4
}

fn test_0_to_m() ? {
    rplx := prepare_test('.{,4}', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "aa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "aaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "aaaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "aaaaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "aaaa"
    assert m.pos == 4

    line = "aaab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "aaab"
    assert m.pos == 4

    line = "b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "b"
    assert m.pos == 1

    line = "baaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "baaa"
    assert m.pos == 4
}

fn test_n_to_many() ? {
    rplx := prepare_test('.{2,}', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0

    line = "aa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "aaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "aaaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "aaaaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "aaab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "aaab"
    assert m.pos == 4

    line = "b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0

    line = "baaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "baaa"
    assert m.pos == 4
}
