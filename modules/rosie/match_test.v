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
    rplx_file := dir(@FILE) + "/test_data/find-net.any.rplx"

    // What exactly are the Encoders about?
    json_encoder := rosie.Encoder{ open: rosie.json_open, close: rosie.json_close }
    //noop_encoder := rosie.Encoder{ open: rosie.noop_open, close: rosie.noop_close }
    //debug_encoder := rosie.Encoder{ open: debug_Open, close: debug_Close }

    debug := 0
    rplx := rosie.load_rplx(rplx_file, debug)?

    m := rosie.new_match(rplx, json_encoder)

    line := "This is my test data"
    err = m.vm_match(line, encoder) 
    if err != 0 { 
        return error("expected successful match")
    }

    if m.matched {
        print(line)
        print(m.stats)
    }

    assert false
}
