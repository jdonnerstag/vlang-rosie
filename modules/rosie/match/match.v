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

fn main() {
    if os.args.len != 3 {
        eprintln("Usage: ${os.args[0]} <rplx_file> <input_file>")
        exit(-1)
    }

    json_encoder := rosie.Encoder{ open: rosie.json_open, close: rosie.json_close }
    //noop_encoder := rosie.Encoder{ open: rosie.noop_open, close: rosie.noop_close }
    //debug_encoder := rosie.Encoder{ open: debug_Open, close: debug_Close }

    encoder := json_encoder

    rplx := rosie.load_rplx(argv[1],  &c) or {
        eprintln("Failed loading the rplx file to load successfully; $err")
        exit(-1)
    }

    fd := os.open_file(os.args[2], "rt")
    defer { fd.close() }

    m := rosie.new_match(rplx, encoder)

    for {
        line := fd.read_line() or { break }
        err = m.vm_match(line, encoder) 
        if err != 0 { 
            eprintln("expected successful match")
            exit(1)
        }
        if m.matched {
            print(line)
            print(m.stats)
        }
    }
}
