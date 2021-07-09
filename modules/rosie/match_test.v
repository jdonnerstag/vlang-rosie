module main

import os
import rosie


fn test_simple_00() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "abc"

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := "abc"
    mut m := rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.matched == true
    assert m.has_match(s00) == true
    assert m.get_match()? == "abc"
    assert m.get_match_by(s00)? == "abc"
    assert m.pos == 3
    assert m.leftover().len == 0
    assert m.get_match_names() == [s00]

    line = "abcde"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.matched == true
    assert m.has_match(s00) == true
    assert m.get_match_by(s00)? == "abc"
    assert m.pos == 3
    assert m.leftover() == "de"

    line = "aaa"
    m = rosie.new_match(rplx, 0)
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
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := "a"
    mut m := rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "a"
    assert m.pos == 1

    line = "aaa"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aaa"
    assert m.pos == 3

    line = "aaab"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aaa"
    assert m.pos == 3

    line = "baaa"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0
}

fn test_simple_02() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "abc"+

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := "abc"
    mut m := rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "abc"
    assert m.pos == 3

    line = "abcabcabc"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "abcabcabc"
    assert m.pos == 9

    line = "abcaaa"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "abc"
    assert m.pos == 3

    line = "baaa"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0
}

fn test_simple_03() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // {"a"+ "b"}

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := "ab"
    mut m := rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "ab"
    assert m.pos == 2

    line = "aab"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aab"
    assert m.pos == 3

    line = "aabc"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aab"
    assert m.pos == 3

    line = "ac"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = ""
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0
}

fn test_simple_04() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "a"*

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := "a"
    mut m := rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "a"
    assert m.pos == 1

    line = "aa"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aa"
    assert m.pos == 2

    line = "aab"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aa"
    assert m.pos == 2

    line = "ba"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == ""
    assert m.pos == 0

    line = ""
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == ""
    assert m.pos == 0
}

fn test_simple_05() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "abc"*

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := "abc"
    mut m := rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "abc"
    assert m.pos == 3

    line = "abcabcabc"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "abcabcabc"
    assert m.pos == 9

    line = "abcabcdd"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "abcabc"
    assert m.pos == 6

    line = "dabc"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == ""
    assert m.pos == 0

    line = ""
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == ""
    assert m.pos == 0
}

fn test_simple_06() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // {"a"* "b"}

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := "ab"
    mut m := rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "ab"
    assert m.pos == 2

    line = "aab"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aab"
    assert m.pos == 3

    line = "b"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "b"
    assert m.pos == 1

    line = ""
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0
}

fn test_simple_07() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "a"{2,4}

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := "aa"
    mut m := rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aa"
    assert m.pos == 2

    line = "aaa"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aaa"
    assert m.pos == 3

    line = "aaaa"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aaaa"
    assert m.pos == 4

    line = "aaaab"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aaaa"
    assert m.pos == 4

    line = "a"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = ""
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0
}

fn test_simple_08() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "abc"{2,4}

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := "abcabc"
    mut m := rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "abcabc"
    assert m.pos == 6

    line = "abcabcabc"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "abcabcabc"
    assert m.pos == 9

    line = "abcabcabcabc"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "abcabcabcabc"
    assert m.pos == 12

    line = "abcabcabcabc1"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "abcabcabcabc"
    assert m.pos == 12

    line = "abc"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = ""
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0
}

fn test_simple_09() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // {"a"{2,4} "b"}

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := "aab"
    mut m := rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aab"
    assert m.pos == 3

    line = "aaab"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aaab"
    assert m.pos == 4

    line = "aaaab"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aaaab"
    assert m.pos == 5

    line = "aaaab1"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "aaaab"
    assert m.pos == 5

    line = "ab"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = "aaaaab"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = ""
    m = rosie.new_match(rplx, 0)
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
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.pos == line.len

    line = "a"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.pos == line.len

    line = "ab"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.pos == line.len

    line = "whatever this is"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.pos == line.len
}

fn test_simple_11() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // {"a" .*}

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = "a"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.pos == line.len

    line = "ab"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.pos == line.len

    line = "a whatever this is"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.pos == line.len

    line = "ba"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    if _ := m.captures.find(s00, line) {assert false }
    assert m.pos == 0
}

fn test_simple_12() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // {.* "a"}

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == line.len

    line = "a"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = "ab"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = "whatever this is"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0
}

fn test_simple_13() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // {{ !"a" . }* "a"}

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == line.len

    line = "a"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.pos == 1

    line = "ab"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "a"
    assert m.pos == 1

    line = "aa"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "a"
    assert m.pos == 1

    line = "123456 aba"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "123456 a"
    assert m.pos == 8

    line = "whatever this is"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "wha"
    assert m.pos == 3
}

fn test_simple_14() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // find:"a"

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == line.len

    line = "a"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.pos == 1

    line = "ab"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "a"
    assert m.pos == 1

    line = "aa"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "a"
    assert m.pos == 1

    line = "123456 aba"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "123456 a"
    assert m.pos == 8

    line = "whatever this is"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "wha"
    assert m.pos == 3
}

fn test_simple_15() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "a" "b"

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == line.len

    line = "a"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = "ab"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = "a b"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.pos == line.len

    line = "a bc"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "a b"
    assert m.pos == 3

    line = "a  \t b"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.pos == line.len
}

fn test_simple_16() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "a" / "bc

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == line.len

    line = "a"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "a"
    assert m.pos == 1

    line = "ab"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "a"
    assert m.pos == 1

    line = "b"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = "bc"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "bc"
    assert m.pos == 2
}

fn test_simple_17() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // {"a" / "b"} "c"

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == line.len

    line = "a"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = "ab"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = "ac"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "ac"
    assert m.pos == 2

    line = "bc"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "bc"
    assert m.pos == 2

    line = "bcd"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "bc"
    assert m.pos == 2
}

fn test_simple_18() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // s17 = {{"a" / "b"} "c"}; s18 = "1" { s17 "d" }

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == line.len

    line = "1 acd"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.captures.find("s17", line)? == "ac"
    assert m.pos == line.len

    line = "1 bcd"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.captures.find("s17", line)? == "bc"
    assert m.pos == line.len

    line = "1 bcd222"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "1 bcd"
    assert m.captures.find("s17", line)? == "bc"
    assert m.pos == 5

    line = "1 bc1"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0
}

fn test_simple_19() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // { [[.][a-z]]+ <".com" }

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == line.len

    line = "www.google.com"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.pos == line.len

    line = "www.google.de"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0
}

fn test_simple_20() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // s20 = s17 / s18 / s19

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    if _ := m.captures.find("s17", line) { assert false }
    if _ := m.captures.find("s18", line) { assert false }
    if _ := m.captures.find("s18", line) { assert false }
    assert m.pos == line.len

    line = "www.google.com"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match()? == line
    assert m.get_match_by(s00)? == line
    assert m.pos == line.len
    assert m.get_match_names() == ["s20", "s19"]

    line = "www.google.de"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0
    
    line = "1 acd"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.captures.find("s17", line)? == "ac"
    assert m.pos == line.len
    assert m.get_match_names() == ["s20", "s18", "s17"]

    line = "1 bcd"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.captures.find("s17", line)? == "bc"
    assert m.pos == line.len

    line = "1 bcd222"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "1 bcd"
    assert m.captures.find("s17", line)? == "bc"
    assert m.pos == 5

    line = "1 bc1"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = "a"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = "ab"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0

    line = "ac"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "ac"
    assert m.pos == 2
    assert m.get_match_names() == ["s20", "s17"]

    line = "bc"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "bc"
    assert m.pos == 2

    line = "bcd"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == "bc"
    assert m.pos == 2
}

fn test_simple_21() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // s20 = find:{ net.any <".com" }

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == line.len

    line = "www.google.com"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.get_match_by(s00)? == line
    assert m.pos == line.len

    // m.captures.print(true)

    line = "www.google.de"
    m = rosie.new_match(rplx, 0)
    assert m.vm_match(line) == false
    assert m.has_match(s00) == false
    assert m.pos == 0
}
/* */
