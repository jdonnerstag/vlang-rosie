module compiler

import rosie.runtime as rt

fn test_codegen() ? {
    mut compst := CompileState{}
    tree := []TTree{}
    fl := rt.new_charset(false)
    compst.codegen(0, false, 0, fl)?
}