module compiler_backend_vm

import rosie.runtime_v2 as rt


fn prepare_test(rpl string, name string, debug int) ? rt.Rplx {
    eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
    rplx := parse_and_compile(rpl: rpl, name: name, debug: debug, unit_test: false)?
    if debug > 0 { rplx.disassemble() }
	return rplx
}

fn test_char() ? {
    rplx := prepare_test('"a" "b"', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == line.len

    line = "a b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a b"
    assert m.pos == 3

    line = "a b "
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a b"
    assert m.pos == 3
}

fn test_simple_01() ? {
    rplx := prepare_test('a = "a"; b = "b"; c = a b', "c", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("a") == false
    assert m.has_match("b") == false
    assert m.has_match("c") == false
    assert m.pos == line.len

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("a") == true
    assert m.get_match_by("a")? == "a"
    assert m.has_match("b") == false
    assert m.has_match("c") == false
    assert m.pos == 0

    line = "a "
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("a") == true
    assert m.get_match_by("a")? == "a"
    assert m.has_match("b") == false
    assert m.has_match("c") == false
    assert m.pos == 0

    line = "a b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.has_match("a") == true
    assert m.get_match_by("a")? == "a"
    assert m.has_match("b") == true
    assert m.get_match_by("b")? == "b"
    assert m.has_match("c") == true
    assert m.get_match_by("c")? == "a b"
    assert m.pos == 3

    line = "a b c"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.has_match("a") == true
    assert m.get_match_by("a")? == "a"
    assert m.has_match("b") == true
    assert m.get_match_by("b")? == "b"
    assert m.has_match("c") == true
    assert m.get_match_by("c")? == "a b"
    assert m.pos == 3

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("a") == true
    assert m.get_match_by("a")? == "a"
    assert m.has_match("b") == false
    assert m.has_match("c") == false
    assert m.pos == 0
}

fn test_simple_02() ? {
    rplx := prepare_test('a = "a"; b = a "b"; c = b "c"', "c", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("a") == false
    assert m.has_match("b") == false
    assert m.has_match("c") == false
    assert m.pos == line.len

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("a") == true
    assert m.get_match_by("a")? == "a"
    assert m.has_match("b") == false
    assert m.has_match("c") == false
    assert m.pos == 0

    line = "a "
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("a") == true
    assert m.get_match_by("a")? == "a"
    assert m.has_match("b") == false
    assert m.has_match("c") == false
    assert m.pos == 0

    line = "a b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("a") == true
    assert m.get_match_by("a")? == "a"
    assert m.has_match("b") == true
    assert m.get_match_by("b")? == "a b"
    assert m.has_match("c") == false
    assert m.pos == 0

    line = "a b c"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.has_match("a") == true
    assert m.get_match_by("a")? == "a"
    assert m.has_match("b") == true
    assert m.get_match_by("b")? == "a b"
    assert m.has_match("c") == true
    assert m.get_match_by("c")? == "a b c"
    assert m.pos == 5

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("a") == true
    assert m.get_match_by("a")? == "a"
    assert m.has_match("b") == false
    assert m.has_match("c") == false
    assert m.pos == 0
}

fn test_simple_03() ? {
    rplx := prepare_test('a = "a"; b = (a)+;', "b", 3)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("a") == false
    assert m.has_match("b") == false
    assert m.pos == line.len

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.has_match("a") == true
    assert m.get_match_by("a")? == "a"
    assert m.get_match_by("b")? == "a"
    assert m.pos == 1

    line = "a "
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.has_match("a") == true
    assert m.get_match_by("a")? == "a"
    assert m.get_match_by("b")? == "a"
    assert m.pos == 1

    line = "a a"
    m = rt.new_match(rplx, 99)
    assert m.vm_match(line) == true
    assert m.has_match("a") == true
    assert m.get_match_by("a")? == "a"
    assert m.get_match_by("b")? == "a a"
    assert m.pos == 3

    line = "a a a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.has_match("a") == true
    assert m.get_match_by("a")? == "a"
    assert m.has_match("b") == true
    assert m.get_match_by("b")? == "a a a"
    assert m.pos == 5
}

fn test_simple_04() ? {
    rplx := prepare_test('a = "a"; b = {a}+;', "b", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("a") == false
    assert m.has_match("b") == false
    assert m.pos == line.len

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.has_match("a") == true
    assert m.get_match_by("a")? == "a"
    assert m.get_match_by("b")? == "a"
    assert m.pos == 1

    line = "aa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.has_match("a") == true
    assert m.get_match_by("a")? == "a"
    assert m.get_match_by("b")? == "aa"
    assert m.pos == 2

    line = "aaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.has_match("a") == true
    assert m.get_match_by("a")? == "a"
    assert m.get_match_by("b")? == "aaa"
    assert m.pos == 3

    line = "b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("a") == false
    assert m.has_match("b") == false
    assert m.pos == 0
}

fn test_05() ? {
    rplx := prepare_test('"a"*', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.captures.len == 1
    assert m.captures[0].name == "main.*"

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.captures.len == 1
    assert m.captures[0].name == "main.*"

    line = "aa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.captures.len == 1
    assert m.captures[0].name == "main.*"
}
