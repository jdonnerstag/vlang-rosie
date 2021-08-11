module main

import os

const (
    test_data_dir = os.dir(@FILE) + "/../runtime/test_data/"
)

fn test_print_charset() ? {
    fname := "$test_data_dir/simple_s00.rplx"
    disassemble_file(fname, true, true, true)?
    //assert false
}
