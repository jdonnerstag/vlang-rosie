module compiler_backend_vm

import rosie.runtime as rt


fn prepare_test(rpl string, name string, debug int) ? rt.Rplx {
    eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
    rplx := parse_and_compile(rpl, name, debug)?
    if debug > 0 { rplx.disassemble() }
	return rplx
}

fn test_char() ? {
    rplx := prepare_test('"a"', "*", 99)?
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
    assert m.vm_match(line) == false
    if _ := m.get_match_by("*") { assert false }
    assert m.pos == 0

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.pos == 1

    line = "ba"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0
}
/*
fn test_simple_01() ? {
    rplx := prepare_test('"a"+', "*", 0)?
    mut line := "a"
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.pos == 1

    line = "aaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "aaa"
    assert m.pos == 3

    line = "aaab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "aaa"
    assert m.pos == 3

    line = "baaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0
}


fn test_simple_03() ? {
    rplx := prepare_test('{"a"+ "b"}', "*", 0)?
    mut line := "ab"
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "ab"
    assert m.pos == 2

    line = "aab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "aab"
    assert m.pos == 3

    line = "aabc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "aab"
    assert m.pos == 3

    line = "ac"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0

    line = ""
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0
}

fn test_simple_04() ? {
    rplx := prepare_test('"a"*', "*", 0)?
    mut line := "a"
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.pos == 1

    line = "aa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "aa"
    assert m.pos == 2

    line = "aab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "aa"
    assert m.pos == 2

    line = "ba"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == ""
    assert m.pos == 0

    line = ""
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == ""
    assert m.pos == 0
}

fn test_simple_06() ? {
    rplx := prepare_test('{"a"* "b"}', "*", 0)?
    mut line := "ab"
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "ab"
    assert m.pos == 2

    line = "aab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "aab"
    assert m.pos == 3

    line = "b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "b"
    assert m.pos == 1

    line = ""
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0
}

fn test_simple_07() ? {
    rplx := prepare_test('"a"{2,4}', "*", 0)?
    mut line := "aa"
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "aa"
    assert m.pos == 2

    line = "aaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "aaa"
    assert m.pos == 3

    line = "aaaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "aaaa"
    assert m.pos == 4

    line = "aaaab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "aaaa"
    assert m.pos == 4

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0

    line = ""
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0
}

fn test_simple_09() ? {
    rplx := prepare_test('{"a"{2,4} "b"}', "*", 0)?
    mut line := "aab"
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "aab"
    assert m.pos == 3

    line = "aaab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "aaab"
    assert m.pos == 4

    line = "aaaab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "aaaab"
    assert m.pos == 5

    line = "aaaab1"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "aaaab"
    assert m.pos == 5

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0

    line = "aaaaab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0

    line = ""
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0
}

fn test_simple_09a() ? {
    rplx := prepare_test('!"a"', "*", 0)?
    rplx.disassemble()
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true     // !pat also matches "no more input"
    assert m.get_match_by("*")? == ""
    assert m.pos == 0

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    if _ := m.get_match_by("*") { assert false }
    assert m.pos == 0

    line = "b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == ""   // look-aheads, such as ! == !>, DO NOT consume input
    assert m.pos == 0
}
*/
