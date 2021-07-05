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
    mut m := rosie.new_match(rplx, 99)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "abc"
    assert m.data.pos == 3

    line = "abcde"
    m = rosie.new_match(rplx, 99)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "abc"
    assert m.data.pos == 3

    line = "aaa"
    m = rosie.new_match(rplx, 99)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.data.pos == 1
}

fn test_simple_01() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "a"+

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := "a"
    mut m := rosie.new_match(rplx, 99)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "a"
    assert m.data.pos == 1

    line = "aaa"
    m = rosie.new_match(rplx, 99)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "aaa"
    assert m.data.pos == 3

    line = "aaab"
    m = rosie.new_match(rplx, 99)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "aaa"
    assert m.data.pos == 3

    line = "baaa"
    m = rosie.new_match(rplx, 99)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.data.pos == 0
}

fn test_simple_02() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "abc"+

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := "abc"
    mut m := rosie.new_match(rplx, 99)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "abc"
    assert m.data.pos == 3

    line = "abcabcabc"
    m = rosie.new_match(rplx, 99)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "abcabcabc"
    assert m.data.pos == 9

    line = "abcaaa"
    m = rosie.new_match(rplx, 99)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "abc"
    assert m.data.pos == 3

    line = "baaa"
    m = rosie.new_match(rplx, 99)
    m.vm_match(line)?
    // eprintln("matched: $m.matched, abend: $m.abend, captures: $m.captures")
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.data.pos == 0
}

fn test_simple_03() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // {"a"+ "b"}

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := "ab"
    mut m := rosie.new_match(rplx, 99)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "ab"
    assert m.data.pos == 2

    line = "aab"
    m = rosie.new_match(rplx, 99)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "aab"
    assert m.data.pos == 3

    line = "aabc"
    m = rosie.new_match(rplx, 99)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "aab"
    assert m.data.pos == 3

    line = "ac"
    m = rosie.new_match(rplx, 99)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.data.pos == 1

    line = ""
    m = rosie.new_match(rplx, 99)
    m.vm_match(line)?
    assert m.matched == false
    if _ := m.captures.find(s00, line) { assert false }
    assert m.data.pos == 0
}

fn test_simple_04() ? {
    s00 := "s" + @FN[@FN.len - 2 ..]
    rplx_file := os.dir(@FILE) + "/test_data/simple_${s00}.rplx"   // "a"*

    eprintln("Load rplx: $rplx_file")
    rplx := rosie.load_rplx(rplx_file, 0)?

    mut line := "a"
    mut m := rosie.new_match(rplx, 99)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "a"
    assert m.data.pos == 1

    line = "aa"
    m = rosie.new_match(rplx, 99)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "aa"
    assert m.data.pos == 2

    line = "aab"
    m = rosie.new_match(rplx, 99)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == "aa"
    assert m.data.pos == 2

    line = "ba"
    m = rosie.new_match(rplx, 99)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == ""
    assert m.data.pos == 0

    line = ""
    m = rosie.new_match(rplx, 99)
    m.vm_match(line)?
    assert m.matched == true
    assert m.captures.find(s00, line)? == ""
    assert m.data.pos == 0
}
