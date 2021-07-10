module main

import os
import rosie.runtime as rt


fn test_simple_00() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "abc"

    eprintln("Load rplx: $rplx_file")
    rplx := rt.load_rplx(rplx_file, 0)?

    mut line := "abc"
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.matched == true
    assert m.has_match(s00) == true
    assert m.get_match()? == "abc"
    assert m.get_match_by(s00)? == "abc"
    assert m.pos == 3
    assert m.leftover().len == 0
    assert m.get_match_names() == [s00]
    assert m.stats.instr_count == 6
    assert m.stats.backtrack_len == 1
    assert m.stats.capture_len == 1
    assert m.stats.match_time.elapsed().nanoseconds() < 100_000

    line = "abcde"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.matched == true
    assert m.has_match(s00) == true
    assert m.get_match_by(s00)? == "abc"
    assert m.pos == 3
    assert m.leftover() == "de"

    line = "aaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.matched == false
    assert m.has_match(s00) == false
    assert m.has_match(s00) == false
    assert m.pos == 0
    assert m.leftover() == "aaa"
}

fn test_simple_01() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "a"+

    eprintln("Load rplx: $rplx_file")
    rplx := rt.load_rplx(rplx_file, 0)?

    mut line := "a"
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "a"
    assert m.pos == 1

    line = "aaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aaa"
    assert m.pos == 3

    line = "aaab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aaa"
    assert m.pos == 3

    line = "baaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0
}

fn test_simple_02() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "abc"+

    eprintln("Load rplx: $rplx_file")
    rplx := rt.load_rplx(rplx_file, 0)?

    mut line := "abc"
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "abc"
    assert m.pos == 3

    line = "abcabcabc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "abcabcabc"
    assert m.pos == 9

    line = "abcaaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "abc"
    assert m.pos == 3

    line = "baaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0
}

fn test_simple_03() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // {"a"+ "b"}

    eprintln("Load rplx: $rplx_file")
    rplx := rt.load_rplx(rplx_file, 0)?

    mut line := "ab"
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "ab"
    assert m.pos == 2

    line = "aab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aab"
    assert m.pos == 3

    line = "aabc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aab"
    assert m.pos == 3

    line = "ac"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = ""
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0
}

fn test_simple_04() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "a"*

    eprintln("Load rplx: $rplx_file")
    rplx := rt.load_rplx(rplx_file, 0)?

    mut line := "a"
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "a"
    assert m.pos == 1

    line = "aa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aa"
    assert m.pos == 2

    line = "aab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aa"
    assert m.pos == 2

    line = "ba"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == ""
    assert m.pos == 0

    line = ""
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == ""
    assert m.pos == 0
}

fn test_simple_05() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "abc"*

    eprintln("Load rplx: $rplx_file")
    rplx := rt.load_rplx(rplx_file, 0)?

    mut line := "abc"
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "abc"
    assert m.pos == 3

    line = "abcabcabc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "abcabcabc"
    assert m.pos == 9

    line = "abcabcdd"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "abcabc"
    assert m.pos == 6

    line = "dabc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == ""
    assert m.pos == 0

    line = ""
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == ""
    assert m.pos == 0
}

fn test_simple_06() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // {"a"* "b"}

    eprintln("Load rplx: $rplx_file")
    rplx := rt.load_rplx(rplx_file, 0)?

    mut line := "ab"
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "ab"
    assert m.pos == 2

    line = "aab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aab"
    assert m.pos == 3

    line = "b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "b"
    assert m.pos == 1

    line = ""
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0
}

fn test_simple_07() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "a"{2,4}

    eprintln("Load rplx: $rplx_file")
    rplx := rt.load_rplx(rplx_file, 0)?

    mut line := "aa"
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aa"
    assert m.pos == 2

    line = "aaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aaa"
    assert m.pos == 3

    line = "aaaa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aaaa"
    assert m.pos == 4

    line = "aaaab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aaaa"
    assert m.pos == 4

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = ""
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0
}

fn test_simple_08() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "abc"{2,4}

    eprintln("Load rplx: $rplx_file")
    rplx := rt.load_rplx(rplx_file, 0)?

    mut line := "abcabc"
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "abcabc"
    assert m.pos == 6

    line = "abcabcabc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "abcabcabc"
    assert m.pos == 9

    line = "abcabcabcabc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "abcabcabcabc"
    assert m.pos == 12

    line = "abcabcabcabc1"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "abcabcabcabc"
    assert m.pos == 12

    line = "abc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = ""
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0
}

fn test_simple_09() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // {"a"{2,4} "b"}

    eprintln("Load rplx: $rplx_file")
    rplx := rt.load_rplx(rplx_file, 0)?

    mut line := "aab"
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aab"
    assert m.pos == 3

    line = "aaab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aaab"
    assert m.pos == 4

    line = "aaaab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aaaab"
    assert m.pos == 5

    line = "aaaab1"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aaaab"
    assert m.pos == 5

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = "aaaaab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = ""
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0
}

fn test_simple_10() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // .* => The ".*" byte code is actually quite complicated

    // TODO looking at the ".*" byte code, it is (a) rather complicated and (b) I think inefficient regarding failure.
    //      I think, upon mismatch, it needs to go through to many hops.

    eprintln("Load rplx: $rplx_file")
    rplx := rt.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.pos == line.len

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.pos == line.len

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.pos == line.len

    line = "whatever this is"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.pos == line.len
}

fn test_simple_11() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // {"a" .*}

    eprintln("Load rplx: $rplx_file")
    rplx := rt.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.pos == line.len

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.pos == line.len

    line = "a whatever this is"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.pos == line.len

    line = "ba"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    if _ := m.captures.find(s00, line) {assert false }
    assert m.pos == 0
}

fn test_simple_12() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // {.* "a"}

    eprintln("Load rplx: $rplx_file")
    rplx := rt.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == line.len

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = "whatever this is"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0
}

fn test_simple_13() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // {{ !"a" . }* "a"}

    eprintln("Load rplx: $rplx_file")
    rplx := rt.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == line.len

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.pos == 1

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "a"
    assert m.pos == 1

    line = "aa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "a"
    assert m.pos == 1

    line = "123456 aba"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "123456 a"
    assert m.pos == 8

    line = "whatever this is"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "wha"
    assert m.pos == 3
}

fn test_simple_14() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // find:"a"

    eprintln("Load rplx: $rplx_file")
    rplx := rt.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == line.len

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.pos == 1

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "a"
    assert m.pos == 1

    line = "aa"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "a"
    assert m.pos == 1

    line = "123456 aba"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "123456 a"
    assert m.pos == 8

    line = "whatever this is"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "wha"
    assert m.pos == 3
}

fn test_simple_15() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "a" "b"

    eprintln("Load rplx: $rplx_file")
    rplx := rt.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == line.len

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = "a b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.pos == line.len

    line = "a bc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "a b"
    assert m.pos == 3

    line = "a  \t b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.pos == line.len
}

fn test_simple_16() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "a" / "bc

    eprintln("Load rplx: $rplx_file")
    rplx := rt.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == line.len

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "a"
    assert m.pos == 1

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "a"
    assert m.pos == 1

    line = "b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = "bc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "bc"
    assert m.pos == 2
}

fn test_simple_17() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // {"a" / "b"} "c"

    eprintln("Load rplx: $rplx_file")
    rplx := rt.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == line.len

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = "ac"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "ac"
    assert m.pos == 2

    line = "bc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "bc"
    assert m.pos == 2

    line = "bcd"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "bc"
    assert m.pos == 2
}

fn test_simple_18() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // s17 = {{"a" / "b"} "c"}; s18 = "1" { s17 "d" }

    eprintln("Load rplx: $rplx_file")
    rplx := rt.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == line.len

    line = "1 acd"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.captures.find("s17", line)? == "ac"
    assert m.pos == line.len

    line = "1 bcd"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.captures.find("s17", line)? == "bc"
    assert m.pos == line.len

    line = "1 bcd222"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "1 bcd"
    assert m.captures.find("s17", line)? == "bc"
    assert m.pos == 5

    line = "1 bc1"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0
}

fn test_simple_19() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // { [[.][a-z]]+ <".com" }

    eprintln("Load rplx: $rplx_file")
    rplx := rt.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == line.len

    line = "www.google.com"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.pos == line.len

    line = "www.google.de"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0
}

fn test_simple_20() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // s20 = s17 / s18 / s19

    eprintln("Load rplx: $rplx_file")
    rplx := rt.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    if _ := m.captures.find("s17", line) { assert false }
    if _ := m.captures.find("s18", line) { assert false }
    if _ := m.captures.find("s18", line) { assert false }
    assert m.pos == line.len

    line = "www.google.com"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match()? == line
    assert m.get_match_by(s00)? == line
    assert m.pos == line.len
    assert m.get_match_names() == ["s20", "s19"]

    line = "www.google.de"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = "1 acd"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.captures.find("s17", line)? == "ac"
    assert m.pos == line.len
    assert m.get_match_names() == ["s20", "s18", "s17"]

    line = "1 bcd"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.captures.find("s17", line)? == "bc"
    assert m.pos == line.len

    line = "1 bcd222"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "1 bcd"
    assert m.captures.find("s17", line)? == "bc"
    assert m.pos == 5

    line = "1 bc1"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = "ac"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "ac"
    assert m.pos == 2
    assert m.get_match_names() == ["s20", "s17"]

    line = "bc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "bc"
    assert m.pos == 2

    line = "bcd"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "bc"
    assert m.pos == 2
}

fn test_simple_21() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // s20 = find:{ net.any <".com" }

    eprintln("Load rplx: $rplx_file")
    rplx := rt.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == line.len

    line = "www.google.com"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.pos == line.len
    assert m.stats.instr_count == 142
    assert m.stats.backtrack_len == 8
    assert m.stats.capture_len == 6
    assert m.stats.match_time.elapsed().nanoseconds() < 100_000

    // m.captures.print(true)

    line = "www.google.de"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0
    assert m.stats.instr_count == 910
    assert m.stats.backtrack_len == 8
    assert m.stats.capture_len == 62
    assert m.stats.match_time.elapsed().nanoseconds() < 300_000

    // TODO In case of a mismatch, net.any creates 61 (!?!) Captures
    //m.captures.print(false)
    //assert false
}
/* */
