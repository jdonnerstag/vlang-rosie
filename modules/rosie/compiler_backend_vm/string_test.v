module compiler_backend_vm

import rosie.runtime as rt


fn prepare_test(rpl string, name string, debug int) ? rt.Rplx {
    eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
    rplx := parse_and_compile(rpl, name, debug)?
    if debug > 0 { rplx.disassemble() }
	return rplx
}

fn test_single() ? {
    rplx := prepare_test('"ab"', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    if _ := m.get_match_by("*") { assert false }
    assert m.pos == 0

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "aa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    if _ := m.get_match_by("*") { assert false }
    assert m.pos == 0

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    if _ := m.get_match_by("*") { assert false }
    assert m.pos == 0

    line = "ba"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    if _ := m.get_match_by("*") { assert false }
    assert m.pos == 0

    line = "abc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "ab"
    assert m.pos == 2
}

fn test_0_or_more() ? {
    rplx := prepare_test('"ab"*', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "aba"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "ab"
    assert m.pos == 2

    line = "abab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "abab"
    assert m.pos == 4

    line = "bab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == ""
    assert m.pos == 0

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == ""
    assert m.pos == 0

    line = "ac"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == ""
    assert m.pos == 0
}

fn test_0_or_1() ? {
    rplx := prepare_test('"ab"?', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "aba"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "ab"
    assert m.pos == 2

    line = "abab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "ab"
    assert m.pos == 2

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == ""
    assert m.pos == 0

    line = "a1"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == ""
    assert m.pos == 0
}

fn test_1_or_more() ? {
    rplx := prepare_test('"ab"+', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    if _ := m.get_match_by("*") { assert false }
    assert m.pos == 0

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "aba"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "ab"
    assert m.pos == 2

    line = "abab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "abab"
    assert m.pos == 4

    line = "ababc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "abab"
    assert m.pos == 4

    line = "ababac"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "abab"
    assert m.pos == 4

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    if _ := m.get_match_by("*") { assert false }
    assert m.pos == 0

    line = "ac"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    if _ := m.get_match_by("*") { assert false }
    assert m.pos == 0
}

fn test_n_to_m() ? {
    rplx := prepare_test('"ab"{2,4}', "*", 0)?
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

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0

    line = "aba"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0

    line = "abab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "ababa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "abab"
    assert m.pos == 4

    line = "ababab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "ababab"
    assert m.pos == 6

    line = "ababababab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "abababab"
    assert m.pos == 8

    line = "bab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0

    line = "ac"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0
}

fn test_0_to_m() ? {
    rplx := prepare_test('"ab"{,4}', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == ""
    assert m.pos == 0

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "ab"
    assert m.pos == 2

    line = "aba"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "ab"
    assert m.pos == 2

    line = "abab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "abab"
    assert m.pos == 4

    line = "ababababab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "abababab"
    assert m.pos == 8

    line = "ababa123"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "abab"
    assert m.pos == 4

    line = "b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == ""
    assert m.pos == 0

    line = "a0"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == ""
    assert m.pos == 0
}

fn test_n_to_many() ? {
    rplx := prepare_test('"ab"{2,}', "*", 0)?
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

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0

    line = "aba"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0

    line = "abab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "ababa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "abab"
    assert m.pos == 4

    line = "ababab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "ababab"
    assert m.pos == 6

    line = "ab".repeat(20)
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == 40

    line = "b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    if _ := m.get_match_by("*") { assert false }
    assert m.pos == 0

    line = "abac"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    if _ := m.get_match_by("*") { assert false }
    assert m.pos == 0
}