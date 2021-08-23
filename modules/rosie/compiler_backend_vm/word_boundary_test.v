module compiler_backend_vm

import rosie.runtime_v2 as rt


fn prepare_test(rpl string, name string, debug int) ? rt.Rplx {
    eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
    rplx := parse_and_compile(rpl, name, debug)?
    if debug > 0 { rplx.disassemble() }
	return rplx
}

fn test_simple_01() ? {
    rplx := prepare_test('"a" "b"', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == line.len

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

    line = "a b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "a bc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a b"
    assert m.pos == 3

    line = "a b c"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a b"
    assert m.pos == 3

    line = "a  \t b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len
}

fn test_simple_02() ? {
    rplx := prepare_test('("a")+', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == line.len

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.pos == 1

    line = "a a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a a"
    assert m.pos == 3

    line = "a a a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a a a"
    assert m.pos == 5

    line = "a "
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.pos == 1

    line = "aa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.pos == 1

    line = "b a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    if _ := m.get_match_by("*") { assert false }
    assert m.pos == 0
}

fn test_simple_03() ? {
    rplx := prepare_test('("a")*', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.pos == 1

    line = "a "
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.pos == 1

    line = "a a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a a"
    assert m.pos == 3

    line = "a a "
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a a"
    assert m.pos == 3

    line = "aa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.pos == 1

    line = "b a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == ""
    assert m.pos == 0
}

fn test_simple_04() ? {
    rplx := prepare_test('"a" "b"? "c"', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == line.len

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

    line = "abc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0

    line = "a b c"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a b c"
    assert m.pos == line.len

    line = "a c"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a c"
    assert m.pos == line.len
}

fn test_simple_05() ? {
    rplx := prepare_test('"a" ("b" / "c") "d"', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == line.len

    line = "a b d"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "a c d"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len
}

fn test_simple_06() ? {
    rplx := prepare_test('"a" ("a")*', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == line.len

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "a "
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "a a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a a"
    assert m.pos == 3

    line = "a a "
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a a"
    assert m.pos == 3

    line = "a aa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a a"
    assert m.pos == 3

    line = "aa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
}

/*
fn test_simple_05() ? {
    rplx := prepare_test('alias ~ = [:space:]+; x = "a" "b"? "c"', "x", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("x") == false
    assert m.pos == line.len

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("x") == false
    assert m.pos == 0

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("x") == false
    assert m.pos == 0

    line = "abc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("x") == false
    assert m.pos == 0

    line = "a b c"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("x")? == "a b c"
    assert m.pos == line.len

    line = "a c"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("x")? == "a c"
    assert m.pos == line.len
}
*/