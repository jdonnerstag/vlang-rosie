module compiler_backend_vm

import rosie.runtime as rt


fn prepare_test(rpl string, name string, debug int) ? rt.Rplx {
    eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
    rplx := parse_and_compile(rpl, name, debug)?
    if debug > 0 { rplx.disassemble() }
	return rplx
}

fn test_find_char() ? {
    rplx := prepare_test('find:"a"', "*", 0)?
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

    line = "aaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.captures.find_cap("*", false)?.start_pos == 0
    assert m.captures.find_cap("*", false)?.end_pos == 1
    assert m.pos == 1

    line = "bbba"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.captures.find_cap("*", false)?.start_pos == 3
    assert m.captures.find_cap("*", false)?.end_pos == 4
    assert m.pos == line.len
}

fn test_find_ci_char() ? {
    rplx := prepare_test('find:ci:"a"', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    if _ := m.get_match_by("*") { assert false }
    assert m.pos == 0

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "A"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "aaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.pos == 1

    line = "bbba"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.captures.find_cap("*", false)?.start_pos == 3
    assert m.captures.find_cap("*", false)?.end_pos == 4
    assert m.pos == line.len

    line = "BbBa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.captures.find_cap("*", false)?.start_pos == 3
    assert m.captures.find_cap("*", false)?.end_pos == 4
    assert m.pos == line.len
}

fn test_find_ci_string() ? {
    rplx := prepare_test('find:ci:"ab"', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    if _ := m.get_match_by("*") { assert false }
    assert m.pos == 0

    line = "123ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "ab"
    assert m.pos == 5

    line = "123Ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "Ab"
    assert m.pos == 5
}

fn test_find_ci_charset() ? {
    rplx := prepare_test('find:ci:[a]', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    if _ := m.get_match_by("*") { assert false }
    assert m.pos == 0

    line = "123a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.pos == 4

    line = "123Ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "A"
    assert m.pos == 4

    line = "1234"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    if _ := m.get_match_by("*") { assert false }
    assert m.pos == 0
}
