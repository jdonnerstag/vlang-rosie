module compiler_backend_vm

import rosie.runtime_v2 as rt


fn prepare_test(rpl string, name string, debug int) ? rt.Rplx {
    eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
    rplx := parse_and_compile(rpl: rpl, name: name, debug: debug, unit_test: false)?
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
    assert m.get_match_by("*", "find:*")? == "a"
    assert m.pos == 1

    line = "aaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.captures.find_cap("main.*", false)?.start_pos == 0
    assert m.captures.find_cap("main.*", false)?.end_pos == 1
    assert m.get_match_by("find:*")? == "a"
    assert m.pos == 1

    line = "bbba"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "bbba"
    assert m.captures.find_cap("main.*", false)?.start_pos == 0
    assert m.captures.find_cap("main.*", false)?.end_pos == 4
    assert m.get_match_by("find:*")? == "a"
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
    assert m.get_match_by("*")? == "bbba"
    assert m.captures.find_cap("main.*", false)?.start_pos == 0
    assert m.captures.find_cap("main.*", false)?.end_pos == 4
    assert m.pos == line.len

    line = "BbBa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "BbBa"
    assert m.captures.find_cap("main.*", false)?.start_pos == 0
    assert m.captures.find_cap("main.*", false)?.end_pos == 4
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
    assert m.get_match_by("*")? == "123ab"
    assert m.pos == 5

    line = "123Ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "123Ab"
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
    assert m.get_match_by("*")? == "123a"
    assert m.pos == 4

    line = "123Ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "123A"
    assert m.pos == 4

    line = "1234"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    if _ := m.get_match_by("*") { assert false }
    assert m.pos == 0
}

fn test_backref() ? {
    rplx := prepare_test('
        delimiter = [+/|]

        grammar
            balanced = { delimiter balanced backref:delimiter } / ""
        end', "balanced", 0)?

    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("balanced")? == line
    assert m.pos == line.len

    line = "++"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("balanced")? == line
    assert m.get_match_by("delimiter")? == "+"
    assert m.pos == line.len

    line = "a+"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true             // Note: The result is true, because of "" matching everything, the 'balanced' is empty.
    assert m.get_match_by("balanced")? == ""
    assert m.pos == 0

    line = "+||+"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("balanced")? == line
    assert m.get_match_by("delimiter")? == "+"
    assert m.get_match_by("balanced", "delimiter")? == "+"
    assert m.get_match_by("balanced", "balanced", "delimiter")? == "|"  // note: you can follow the match path to find the 2nd delimiter
    assert m.pos == line.len

    line = "+|/+"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("balanced")? == ""
    assert m.pos == 0
}

fn test_onetag() ? {
    rplx := prepare_test('import ../test/backref-rpl as bref; x = bref.onetag', "x", 0)?

    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false

    line = "<foo></foo>"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("x")? == line
    assert m.pos == line.len

    line = "<foo> blah blah b</foo>"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("x")? == line
    assert m.get_match_by("x")? == line
    assert m.pos == line.len

    line = "<foo> blah blah b</foo2>"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
}

fn test_nested_html() ? {
    rplx := prepare_test('import ../test/backref-rpl as bref; x = bref.html', "x", 3)?

    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false

    line = "<foo><bar></bar></foo>"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("x")? == line
    assert m.pos == line.len

    line = "<foo></foo><bar></bar>"
    m = rt.new_match(rplx, 20)
    assert m.vm_match(line) == true
    assert m.get_match_by("x")? == line
    assert m.pos == line.len
}
/* */
