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
    rplx_file := os.dir(@FILE) + "/test_data/simple_s00.rplx"   // "abc"

    eprintln("Load rplx: $rplx_file")
    debug := 0
    rplx := rosie.load_rplx(rplx_file, debug)?

    mut m := rosie.new_match(rplx)
    m.debug = 99

    mut line := "abc"
    mut err := m.vm_match(line)?
    assert err == rosie.MatchErrorCodes.ok 
    assert m.matched == true
    assert m.captures.find("s00", line)? == "abc"
    assert m.data.pos == 3

    line = "abcde"
    m = rosie.new_match(rplx)
    err = m.vm_match(line)?
    assert err == rosie.MatchErrorCodes.ok 
    assert m.matched == true
    assert m.captures.find("s00", line)? == "abc"
    assert m.data.pos == 3

    line = "aaa"
    m = rosie.new_match(rplx)
    err = m.vm_match(line)?
    eprintln("err: $err, matched: $m.matched, abend: $m.abend, captures: $m.captures")
    assert err == rosie.MatchErrorCodes.ok 
    assert m.matched == false
    if _ := m.captures.find("s00", line) { assert false }
    assert m.data.pos == 1
}

fn test_simple_01() ? {
    rplx_file := os.dir(@FILE) + "/test_data/simple_s01.rplx"   // "a"+

    eprintln("Load rplx: $rplx_file")
    debug := 0
    rplx := rosie.load_rplx(rplx_file, debug)?

    mut m := rosie.new_match(rplx)
    m.debug = 99

    mut line := "a"
    mut err := m.vm_match(line)?
    assert err == rosie.MatchErrorCodes.ok 
    assert m.matched == true
    assert m.captures.find("s01", line)? == "a"
    assert m.data.pos == 1

    line = "aaa"
    m = rosie.new_match(rplx)
    err = m.vm_match(line)?
    assert err == rosie.MatchErrorCodes.ok 
    assert m.matched == true
    assert m.captures.find("s01", line)? == "aaa"
    assert m.data.pos == 3

    line = "aaab"
    m = rosie.new_match(rplx)
    err = m.vm_match(line)?
    assert err == rosie.MatchErrorCodes.ok 
    assert m.matched == true
    assert m.captures.find("s01", line)? == "aaa"
    assert m.data.pos == 3

    line = "baaa"
    m = rosie.new_match(rplx)
    err = m.vm_match(line)?
    eprintln("err: $err, matched: $m.matched, abend: $m.abend, captures: $m.captures")
    assert err == rosie.MatchErrorCodes.ok 
    assert m.matched == false
    if _ := m.captures.find("s01", line) { assert false }
    assert m.data.pos == 0
}
