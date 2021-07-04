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

fn test_match() ? {
    rplx_file := os.dir(@FILE) + "/test_data/simple_1.rplx"

    // What exactly are the Encoders about?
    json_encoder := rosie.Encoder{ open: rosie.json_open, close: rosie.json_close }
    //noop_encoder := rosie.Encoder{ open: rosie.noop_open, close: rosie.noop_close }
    //debug_encoder := rosie.Encoder{ open: debug_Open, close: debug_Close }

    eprintln("Load rplx: $rplx_file")
    debug := 0
    rplx := rosie.load_rplx(rplx_file, debug)?

    mut m := rosie.new_match(rplx, json_encoder)
    m.debug = 99

    mut line := "abc"
    mut err := m.vm_match(line, json_encoder)?
    assert err == rosie.MatchErrorCodes.ok 
    assert m.matched == true
    assert m.captures.find("x", line)? == "abc"
    assert m.data.pos == 3

    line = "abcde"
    m = rosie.new_match(rplx, json_encoder)
    err = m.vm_match(line, json_encoder)?
    assert err == rosie.MatchErrorCodes.ok 
    assert m.matched == true
    assert m.captures.find("x", line)? == "abc"
    assert m.data.pos == 3

    line = "aaa"
    m = rosie.new_match(rplx, json_encoder)
    err = m.vm_match(line, json_encoder)?
    eprintln("err: $err, matched: $m.matched, abend: $m.abend, captures: $m.captures")
    assert err == rosie.MatchErrorCodes.ok 
    assert m.matched == false
    if _ := m.captures.find("x", line) { assert false }
    assert m.data.pos == 1

    assert false
}
