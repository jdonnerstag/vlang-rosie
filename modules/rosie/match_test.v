module main

import os
import rosie

//  -*- Mode: C/l; -*-                                                       
//                                                                           
//  match.c                                                                  
//                                                                           
//  © Copyright Jamie A. Jennings 2018, 2019.                                
//  LICENSE: MIT License (https://opensource.org/licenses/mit-license.html)  
//  AUTHOR: Jamie A. Jennings                                                

//  THIS IS ONLY A TEST!  IT IS A PROOF OF CONCEPT ILLUSTRATING HOW SMALL
//  AN EXECUTABLE COULD BE IF IT CONTAINS ONLY THE ROSIE RUN-TIME.

//  gcc match.c -o match -I../include ../runtime/*.o
//  ./match data/findall:net.ipv4.rplx data/log10.txt | json_pp

fn test_simple_00() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "abc"

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := "abc"
    mut m := rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "abc"
    assert m.pos == 3

    line = "abcde"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "abc"
    assert m.pos == 3

    line = "aaa"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == 0
}

fn test_simple_01() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "a"+

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := "a"
    mut m := rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "a"
    assert m.pos == 1

    line = "aaa"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "aaa"
    assert m.pos == 3

    line = "aaab"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "aaa"
    assert m.pos == 3

    line = "baaa"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == 0
}

fn test_simple_02() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "abc"+

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := "abc"
    mut m := rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "abc"
    assert m.pos == 3

    line = "abcabcabc"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "abcabcabc"
    assert m.pos == 9

    line = "abcaaa"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "abc"
    assert m.pos == 3

    line = "baaa"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == 0
}

fn test_simple_03() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // {"a"+ "b"}

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := "ab"
    mut m := rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "ab"
    assert m.pos == 2

    line = "aab"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "aab"
    assert m.pos == 3

    line = "aabc"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "aab"
    assert m.pos == 3

    line = "ac"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == 0

    line = ""
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == 0
}

fn test_simple_04() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "a"*

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := "a"
    mut m := rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "a"
    assert m.pos == 1

    line = "aa"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "aa"
    assert m.pos == 2

    line = "aab"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "aa"
    assert m.pos == 2

    line = "ba"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == ""
    assert m.pos == 0

    line = ""
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == ""
    assert m.pos == 0
}

fn test_simple_05() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "abc"*

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := "abc"
    mut m := rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "abc"
    assert m.pos == 3

    line = "abcabcabc"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "abcabcabc"
    assert m.pos == 9

    line = "abcabcdd"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "abcabc"
    assert m.pos == 6

    line = "dabc"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == ""
    assert m.pos == 0

    line = ""
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == ""
    assert m.pos == 0
}

fn test_simple_06() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // {"a"* "b"}

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := "ab"
    mut m := rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "ab"
    assert m.pos == 2

    line = "aab"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "aab"
    assert m.pos == 3

    line = "b"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "b"
    assert m.pos == 1

    line = ""
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == 0
}

fn test_simple_07() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "a"{2,4}

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := "aa"
    mut m := rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "aa"
    assert m.pos == 2

    line = "aaa"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "aaa"
    assert m.pos == 3

    line = "aaaa"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "aaaa"
    assert m.pos == 4

    line = "aaaab"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "aaaa"
    assert m.pos == 4

    line = "a"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == 0

    line = ""
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == 0
}

fn test_simple_08() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "abc"{2,4}

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := "abcabc"
    mut m := rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "abcabc"
    assert m.pos == 6

    line = "abcabcabc"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "abcabcabc"
    assert m.pos == 9

    line = "abcabcabcabc"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "abcabcabcabc"
    assert m.pos == 12

    line = "abcabcabcabc1"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "abcabcabcabc"
    assert m.pos == 12

    line = "abc"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == 0

    line = ""
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == 0
}

fn test_simple_09() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // {"a"{2,4} "b"}

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := "aab"
    mut m := rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "aab"
    assert m.pos == 3

    line = "aaab"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "aaab"
    assert m.pos == 4

    line = "aaaab"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "aaaab"
    assert m.pos == 5

    line = "aaaab1"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "aaaab"
    assert m.pos == 5

    line = "ab"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == 0

    line = "aaaaab"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == 0

    line = ""
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
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
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == line
    assert m.pos == line.len

    line = "a"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == line
    assert m.pos == line.len

    line = "ab"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == line
    assert m.pos == line.len

    line = "whatever this is"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == line
    assert m.pos == line.len
}

fn test_simple_11() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // {"a" .*}

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == 0

    line = "a"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == line
    assert m.pos == line.len

    line = "ab"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == line
    assert m.pos == line.len

    line = "a whatever this is"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == line
    assert m.pos == line.len

    line = "ba"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
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
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == line.len

    line = "a"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == 0

    line = "ab"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == 0

    line = "whatever this is"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == 0
}

fn test_simple_13() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // {{ !"a" . }* "a"}

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == line.len

    line = "a"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == line
    assert m.pos == 1

    line = "ab"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "a"
    assert m.pos == 1

    line = "aa"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "a"
    assert m.pos == 1

    line = "123456 aba"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "123456 a"
    assert m.pos == 8

    line = "whatever this is"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "wha"
    assert m.pos == 3
}

fn test_simple_14() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // find:"a"

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == line.len

    line = "a"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == line
    assert m.pos == 1

    line = "ab"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "a"
    assert m.pos == 1

    line = "aa"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "a"
    assert m.pos == 1

    line = "123456 aba"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "123456 a"
    assert m.pos == 8

    line = "whatever this is"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "wha"
    assert m.pos == 3
}

fn test_simple_15() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "a" "b"

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == line.len

    line = "a"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == 0

    line = "ab"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == 0

    line = "a b"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == line
    assert m.pos == line.len

    line = "a bc"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "a b"
    assert m.pos == 3

    line = "a  \t b"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == line
    assert m.pos == line.len
}

fn test_simple_16() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "a" / "bc

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == line.len

    line = "a"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "a"
    assert m.pos == 1

    line = "ab"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "a"
    assert m.pos == 1

    line = "b"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == 0

    line = "bc"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "bc"
    assert m.pos == 2
}

fn test_simple_17() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // {"a" / "b"} "c"

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == line.len

    line = "a"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == 0

    line = "ab"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == 0

    line = "ac"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "ac"
    assert m.pos == 2

    line = "bc"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "bc"
    assert m.pos == 2

    line = "bcd"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "bc"
    assert m.pos == 2
}

fn test_simple_18() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // s17 = {{"a" / "b"} "c"}; s18 = "1" { s17 "d" }

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == line.len

    line = "1 acd"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == line
    assert m.captures.find("s17", line)? == "ac"
    assert m.pos == line.len

    line = "1 bcd"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == line
    assert m.captures.find("s17", line)? == "bc"
    assert m.pos == line.len

    line = "1 bcd222"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "1 bcd"
    assert m.captures.find("s17", line)? == "bc"
    assert m.pos == 5

    line = "1 bc1"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == 0
}

fn test_simple_19() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // { [[.][a-z]]+ <".com" }

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == line.len

    line = "www.google.com"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == line
    assert m.pos == line.len

    line = "www.google.de"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == 0
}

fn test_simple_20() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // s20 = find:{ net.any <".com" }

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := ""
    mut m := rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == line.len

    line = "www.google.com"
    m = rosie.new_match(rplx, 99)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == line
    assert m.pos == line.len

    line = "www.google.de"
    m = rosie.new_match(rplx, 0)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.pos == 0
}
/* */
