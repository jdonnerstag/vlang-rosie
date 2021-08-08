module compiler_backend_vm

import rosie.parser
import rosie.runtime as rt


fn prepare_test(rpl string, name string, debug int) ? rt.Rplx {
    eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
    rplx := parse_and_compile(rpl, name, debug)?
    if debug > 0 { rplx.disassemble() }
	return rplx
}

fn test_simple_00() ? {
    rplx := prepare_test('"abc"', "*", 0)?
    mut line := "abc"
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.matched == true
    assert m.has_match("*") == true
    assert m.get_match()? == "abc"
    assert m.get_match_by("*")? == "abc"
    assert m.pos == 3
    assert m.leftover().len == 0
    assert m.get_match_names() == ["*"]
    assert m.stats.instr_count == 6
    assert m.stats.backtrack_len == 1
    assert m.stats.capture_len == 1
    assert m.stats.match_time.elapsed().nanoseconds() < 100_000
    assert m.replace("123") == "123"
    assert m.replace_by("*", "123")? == "123"

    line = "abcde"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.matched == true
    assert m.has_match("*") == true
    assert m.get_match_by("*")? == "abc"
    assert m.pos == 3
    assert m.leftover() == "de"
    assert m.replace("123") == "123de"
    assert m.replace_by("*", "123")? == "123de"

    line = "aaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.matched == false
    assert m.has_match("*") == false
    assert m.has_match("*") == false
    assert m.pos == 0
    assert m.leftover() == "aaa"
}

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

fn test_simple_02() ? {
    rplx := prepare_test('"abc"+', "*", 0)?
    mut line := "abc"
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "abc"
    assert m.pos == 3

    line = "abcabcabc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "abcabcabc"
    assert m.pos == 9

    line = "abcaaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "abc"
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

fn test_simple_05() ? {
    rplx := prepare_test('"abc"*', "*", 0)?
    mut line := "abc"
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "abc"
    assert m.pos == 3

    line = "abcabcabc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "abcabcabc"
    assert m.pos == 9

    line = "abcabcdd"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "abcabc"
    assert m.pos == 6

    line = "dabc"
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

fn test_simple_08() ? {
    rplx := prepare_test('"abc"{2,4}', "*", 0)?
    mut line := "abcabc"
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "abcabc"
    assert m.pos == 6

    line = "abcabcabc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "abcabcabc"
    assert m.pos == 9

    line = "abcabcabcabc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "abcabcabcabc"
    assert m.pos == 12

    line = "abcabcabcabc1"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "abcabcabcabc"
    assert m.pos == 12

    line = "abc"
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

fn test_simple_10() ? {
    rplx := prepare_test('.', "*", 0)?
    //rplx.disassemble()
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

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.pos == 1
}

fn test_simple_10a() ? {
    rplx := prepare_test('.*', "*", 0)?
    //rplx.disassemble()
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

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "whatever this is"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len
}

fn test_simple_10b() ? {
    rplx := prepare_test('.?', "*", 0)?
    //rplx.disassemble()
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

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.pos == 1
}

fn test_simple_10c() ? {
    rplx := prepare_test('.+', "*", 0)?
    //rplx.disassemble()
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

    line = "abcdefgh"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len
}

fn test_simple_10d() ? {
    rplx := prepare_test('.{2,4}', "*", 0)?
    //rplx.disassemble()
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    if _ := m.get_match_by("*") { assert false }
    assert m.pos == 0

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    if _ := m.get_match_by("*") { assert false }
    assert m.pos == 0

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "abc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "abcd"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "abcde"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "abcd"
    assert m.pos == 4
}
/*
fn test_simple_11() ? {
    rplx := prepare_test('{"a" .*}', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "a whatever this is"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "ba"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    if _ := m.captures.find("*", line) {assert false }
    assert m.pos == 0
}

fn test_simple_12() ? {
    rplx := prepare_test('{.* "a"}', "*", 0)?
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

    line = "whatever this is"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0
}

fn test_simple_13() ? {
    rplx := prepare_test('{{ !"a" . }* "a"}', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == line.len

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == 1

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.pos == 1

    line = "aa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.pos == 1

    line = "123456 aba"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "123456 a"
    assert m.pos == 8

    line = "whatever this is"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "wha"
    assert m.pos == 3
}

fn test_simple_14() ? {
    rplx := prepare_test('find:"a"', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == line.len

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == 1

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.pos == 1

    line = "aa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.pos == 1

    line = "123456 aba"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "123456 a"
    assert m.pos == 8

    line = "whatever this is"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "wha"
    assert m.pos == 3
}

fn test_simple_15() ? {
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

    line = "a  \t b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len
}

fn test_simple_16() ? {
    rplx := prepare_test('"a" / "bc"', "*", 0)?
    rplx.disassemble()
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

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.pos == 1

    line = "b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0

    line = "bc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "bc"
    assert m.pos == 2
}

fn test_simple_16a() ? {
    rplx := prepare_test('"bc" / "a"', "*", 0)?
    //rplx.disassemble()
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

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.pos == 1

    line = "b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0

    line = "bc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "bc"
    assert m.pos == 2
}

fn test_simple_16b() ? {
    rplx := prepare_test('{"b" "c"} / "a"', "*", 0)?    // Same as 16a
    //rplx.disassemble()
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

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.pos == 1

    line = "b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0

    line = "bc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "bc"
    assert m.pos == 2
}

fn test_simple_16c() ? {
    rplx := prepare_test('"bc" / "a" / "de"', "*", 0)?
    //rplx.disassemble()
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

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.pos == 1

    line = "b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0

    line = "bc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "bc"
    assert m.pos == 2

    line = "de111"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "de"
    assert m.pos == 2
}

fn test_simple_16d() ? {
    rplx := prepare_test('"bc" / [0-9]', "*", 0)?
    //rplx.disassemble()
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == line.len

    line = "5"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "5"
    assert m.pos == 1

    line = "0a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "0"
    assert m.pos == 1

    line = "b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0

    line = "bc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "bc"
    assert m.pos == 2
}

fn test_simple_16e() ? {
    rplx := prepare_test('[0-9] / "bc"', "*", 0)?
    //rplx.disassemble()
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == line.len

    line = "5"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "5"
    assert m.pos == 1

    line = "0a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "0"
    assert m.pos == 1

    line = "b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0

    line = "bc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "bc"
    assert m.pos == 2
}

fn test_simple_16f() ? {
    rplx := prepare_test('"bc" / {"a"}', "*", 0)?
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

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "a"
    assert m.pos == 1

    line = "b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0

    line = "bc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "bc"
    assert m.pos == 2
}

fn test_simple_17() ? {
    rplx := prepare_test('{"a" / "b"} "c"', "*", 0)?
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

    line = "ac"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "ac"
    assert m.pos == 2

    line = "bc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "bc"
    assert m.pos == 2

    line = "bcd"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "bc"
    assert m.pos == 2
}

fn test_simple_18a() ? {
    rplx := prepare_test('s17 = {{"a" / "b"} "c"}; s18 = {"1" { s17 "d" }}', "s18", 0)?
    rplx.disassemble()
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("s18") == false
    assert m.pos == line.len

    line = "1acd"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("s18")? == line
    assert m.get_match_by("s17")? == "ac"
    assert m.pos == line.len

    line = "1bcd"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("s18")? == line
    assert m.get_match_by("s17")? == "bc"
    assert m.pos == line.len

    line = "1bcd222"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("s18")? == "1bcd"
    assert m.get_match_by("s17")? == "bc"
    assert m.pos == 4

    line = "1bc1"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("s18") == false
    assert m.pos == 0
}
/*
fn test_simple_18b() ? {
    rplx := prepare_test('s17 = {{"a" / "b"} "c"}; s18 = "1" { s17 "d" }', "s18", 0)?
    rplx.disassemble()
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("s18") == false
    assert m.pos == line.len

    line = "1 acd"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("s18")? == line
    assert m.captures.find("s17", line)? == "ac"
    assert m.pos == line.len

    line = "1 bcd"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("s18")? == line
    assert m.captures.find("s17", line)? == "bc"
    assert m.pos == line.len

    line = "1 bcd222"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("s18")? == "1 bcd"
    assert m.captures.find("s17", line)? == "bc"
    assert m.pos == 5

    line = "1 bc1"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("s18") == false
    assert m.pos == 0
}
/*
fn test_simple_19() ? {
    rplx := prepare_test('{ [[.][a-z]]+ <".com" }', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == line.len

    line = "www.google.com"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len

    line = "www.google.de"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0
}
/*
fn test_simple_20() ? {
    rplx := prepare_test('s20 = s17 / s18 / s19', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    if _ := m.captures.find("s17", line) { assert false }
    if _ := m.captures.find("s18", line) { assert false }
    if _ := m.captures.find("s18", line) { assert false }
    assert m.pos == line.len

    line = "www.google.com"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match()? == line
    assert m.get_match_by("*")? == line
    assert m.pos == line.len
    assert m.get_match_names() == ["s20", "s19"]

    line = "www.google.de"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0

    line = "1 acd"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.captures.find("s17", line)? == "ac"
    assert m.pos == line.len
    assert m.get_match_names() == ["s20", "s18", "s17"]

    line = "1 bcd"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.captures.find("s17", line)? == "bc"
    assert m.pos == line.len

    line = "1 bcd222"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "1 bcd"
    assert m.captures.find("s17", line)? == "bc"
    assert m.pos == 5

    line = "1 bc1"
    m = rt.new_match(rplx, 0)
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

    line = "ac"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "ac"
    assert m.pos == 2
    assert m.get_match_names() == ["s20", "s17"]

    line = "bc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "bc"
    assert m.pos == 2

    line = "bcd"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == "bc"
    assert m.pos == 2
}
/*
fn test_simple_21() ? {
    rplx := prepare_test('s20 = find:{ net.any <".com" }', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == line.len

    line = "www.google.com"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by("*")? == line
    assert m.pos == line.len
    assert m.stats.instr_count == 142
    assert m.stats.backtrack_len == 8
    assert m.stats.capture_len == 6
    assert m.stats.match_time.elapsed().nanoseconds() < 100_000

    // m.captures.print(true)

    line = "www.google.de"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match("*") == false
    assert m.pos == 0
    assert m.stats.instr_count == 910
    assert m.stats.backtrack_len == 8
    assert m.stats.capture_len == 62
    assert m.stats.match_time.elapsed().nanoseconds() < 600_000

    // TODO In case of a mismatch, net.any creates 61 (!?!) Captures
    //m.captures.print(false)
    //assert false
}
*/
