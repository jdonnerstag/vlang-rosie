module compiler

// import rosie.runtime as rt

fn test_empty_pattern() ? {
    mut p := Pattern{}
    code := compile(&p, 0)?
    assert code.len == 0
}

fn test_simple_char() ? {
    mut p := Pattern{}
    p.tree << TTree{ tag: .tchar, n: "a"[0] }
    code := compile(&p, 99)?
    assert code.len == 2
    assert code[0].opcode() == .char
    assert code[0].aux() == byte(`a`)
    assert code[1].opcode() == .end
}