module compiler

import rosie.runtime as rt

fn test_codegen() ? {
    mut compst := CompileState{}
    tree := []TTree{}
    opt := 0
    tt := 0
    fl := rt.new_charset(false)
    compst.codegen(tree, 0, opt, tt, fl)?
}