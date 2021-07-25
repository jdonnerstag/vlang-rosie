module compiler_backend

import rosie.runtime as rt

fn test_empty_pattern() ? {
    mut p := &Pattern{}
    mut compst := CompileState{ p: p, debug: 0 }

    // compile() gracefully handles it. codegen() will fail.
    if _ := compst.codegen(0, false, -1, fullset) { assert false }
    assert p.code.len == 0

    assert compst.debug == 0
}

fn test_simple_char() ? {
    mut p := &Pattern{}
    mut compst := CompileState{ p: p, debug: 0 }

    p.tree << TTree{ tag: .tchar, n: "a"[0] }
    compst.codegen(0, false, -1, fullset)?
    if compst.debug > 0 { p.code.disassemble(p.kt) }

    assert p.code.len == 1
    assert p.code[0].opcode() == .char
    assert p.code[0].ichar() == byte(`a`)
    assert p.code[0].aux() == int(byte(`a`))
}

fn test_char_protected() ? {
    mut p := &Pattern{}
    mut compst := CompileState{ p: p, debug: 0 }

    tt := p.code.len
    p.code << rt.opcode_to_slot(.test_char).set_char(byte(`a`))
    p.code << rt.Slot(int(5))   // jmp upon failure

    p.tree << TTree{ tag: .tchar, n: "a"[0] }
    compst.codegen(0, false, tt, fullset)?
    if compst.debug > 0 { p.code.disassemble(p.kt) }

    assert p.code.len == 3
    assert p.code[0].opcode() == .test_char
    assert p.code[0].ichar() == byte(`a`)
    assert p.code[0].aux() == int(byte(`a`))
    assert p.code[1].int() == 5
    assert p.code[2].opcode() == .any

    assert compst.debug == 0
}

fn test_char_protected_but_no_test_char() ? {
    mut p := &Pattern{}
    mut compst := CompileState{ p: p, debug: 0 }

    tt := p.code.len
    p.code << rt.opcode_to_slot(.halt)

    p.tree << TTree{ tag: .tchar, n: "a"[0] }
    compst.codegen(0, false, tt, fullset)?
    if compst.debug > 0 { p.code.disassemble(p.kt) }

    assert p.code.len == 2
    assert p.code[0].opcode() == .halt
    assert p.code[1].opcode() == .char
    assert p.code[1].ichar() == byte(`a`)
    assert p.code[1].aux() == int(byte(`a`))

    assert compst.debug == 0
}

fn test_simple_any() ? {
    mut p := &Pattern{}
    mut compst := CompileState{ p: p, debug: 0 }

    p.tree << TTree{ tag: .tany }
    compst.codegen(0, false, -1, fullset)?
    if compst.debug > 0 { p.code.disassemble(p.kt) }

    assert p.code.len == 1
    assert p.code[0].opcode() == .any
    assert p.code[0].aux() == 0

    assert compst.debug == 0
}

fn test_simple_tset() ? {
    mut p := &Pattern{}
    mut compst := CompileState{ p: p, debug: 0 }

    p.charsets << rt.new_charset_with_byte(byte(`1`))
    p.charsets << rt.new_charset(false)
    p.charsets << rt.new_charset(true)
    p.charsets << rt.new_charset(false).set_char(byte(`1`)).set_char(byte(`2`))

    p.tree << TTree{ tag: .tset, key: 0 }
    p.tree << TTree{ tag: .tset, key: 1 }
    p.tree << TTree{ tag: .tset, key: 2 }
    p.tree << TTree{ tag: .tset, key: 3 }

    compst.codegen(0, false, -1, fullset)?
    assert p.code.len == 1
    assert p.code[0].opcode() == .char
    assert p.code[0].ichar() == byte(`1`)
    assert p.code[0].aux() == int("1"[0])

    p.code.clear()
    compst.codegen(1, false, -1, fullset)?
    assert p.code.len == 1
    assert p.code[0].opcode() == .fail
    assert p.code[0].aux() == 0

    p.code.clear()
    compst.codegen(2, false, -1, fullset)?
    assert p.code.len == 1
    assert p.code[0].opcode() == .any
    assert p.code[0].aux() == 0

    p.code.clear()
    compst.codegen(3, false, -1, fullset)?
    assert p.code.len == 9
    assert p.code[0].opcode() == .set
    assert p.code[0].aux() == 0
    assert p.code[1] == rt.Slot(0)
    assert p.code[2] == rt.Slot(0x0006_0000)
    assert p.code[3] == rt.Slot(0)
    assert p.code[4] == rt.Slot(0)
    assert p.code[5] == rt.Slot(0)
    assert p.code[6] == rt.Slot(0)
    assert p.code[7] == rt.Slot(0)
    assert p.code[8] == rt.Slot(0)

    // TODO Add a test where tt >= 0

    assert compst.debug == 0
}

fn test_simple_true() ? {
    mut p := &Pattern{}
    mut compst := CompileState{ p: p, debug: 0 }

    p.tree << TTree{ tag: .ttrue }
    compst.codegen(0, false, -1, fullset)?

    assert p.code.len == 0

    assert compst.debug == 0
}

fn test_simple_false() ? {
    mut p := &Pattern{}
    mut compst := CompileState{ p: p, debug: 0 }

    p.tree << TTree{ tag: .tfalse }
    compst.codegen(0, false, -1, fullset)?
    if compst.debug > 0 { p.code.disassemble(p.kt) }

    assert p.code.len == 1
    assert p.code[0].opcode() == .fail
    assert p.code[0].aux() == 0

    assert compst.debug == 0
}

fn test_simple_halt() ? {
    mut p := &Pattern{}
    mut compst := CompileState{ p: p, debug: 0 }

    p.tree << TTree{ tag: .thalt }
    compst.codegen(0, false, -1, fullset)?
    if compst.debug > 0 { p.code.disassemble(p.kt) }

    assert p.code.len == 1
    assert p.code[0].opcode() == .halt
    assert p.code[0].aux() == 0

    assert compst.debug == 0
}

fn test_simple_tchoice() ? {
    mut p := &Pattern{}
    mut compst := CompileState{ p: p, debug: 0 }

    p.tree << TTree{ tag: .tchoice, ps: 2 }
    p.tree << TTree{ tag: .tany }
    p.tree << TTree{ tag: .tfalse }
    compst.codegen(0, false, -1, fullset)?
    if compst.debug > 0 { p.code.disassemble(p.kt) }

    assert p.code.len == 6
    assert p.code[0].opcode() == .test_any
    assert p.code[1].int() == 4
    assert p.code[2].opcode() == .any
    assert p.code[3].opcode() == .jmp
    assert p.code[4].int() == 2
    assert p.code[5].opcode() == .fail

    assert compst.debug == 0
}

fn test_simple_trep() ? {
    mut p := &Pattern{}
    mut compst := CompileState{ p: p, debug: 0 }

    p.tree << TTree{ tag: .trep }
    p.tree << TTree{ tag: .tfalse }
    compst.codegen(0, false, -1, fullset)?
    if compst.debug > 0 { p.code.disassemble(p.kt) }

    assert p.code.len == 5
    assert p.code[0].opcode() == .jmp
    assert p.code[0].aux() == 0
    assert p.code[1] == rt.Slot(4)
    assert p.code[2].opcode() == .fail
    assert p.code[3].opcode() == .jmp
    assert p.code[4] == rt.Slot(-3)

    assert compst.debug == 0
}

fn test_simple_tbehind() ? {
    mut p := &Pattern{}
    mut compst := CompileState{ p: p, debug: 0 }

    p.tree << TTree{ tag: .tbehind, n: 2 }
    p.tree << TTree{ tag: .tany }
    p.tree << TTree{ tag: .tfalse }
    compst.codegen(0, false, -1, fullset)?
    if compst.debug > 0 { p.code.disassemble(p.kt) }

    assert p.code.len == 2
    assert p.code[0].opcode() == .behind
    assert p.code[0].aux() == 2
    assert p.code[1].opcode() == .any

    assert compst.debug == 0
}

fn test_simple_tnot() ? {
    mut p := &Pattern{}
    mut compst := CompileState{ p: p, debug: 0 }

    p.tree << TTree{ tag: .tnot }
    p.tree << TTree{ tag: .tany }
    p.tree << TTree{ tag: .tfalse }
    compst.codegen(0, false, -1, fullset)?
    if compst.debug > 0 { p.code.disassemble(p.kt) }

    assert p.code.len == 3
    assert p.code[0].opcode() == .test_any
    assert p.code[0].aux() == 0
    assert p.code[1].int() == 2
    assert p.code[2].opcode() == .fail

    assert compst.debug == 0
}

fn test_simple_tand() ? {
    mut p := &Pattern{}
    mut compst := CompileState{ p: p, debug: 0 }

    p.tree << TTree{ tag: .tand }
    p.tree << TTree{ tag: .tany }
    p.tree << TTree{ tag: .tfalse }
    compst.codegen(0, false, -1, fullset)?

    if compst.debug > 0 { p.code.disassemble(p.kt) }
    assert p.code.len == 2
    assert p.code[0].opcode() == .any
    assert p.code[1].opcode() == .behind
    assert p.code[1].aux() == 1

    assert compst.debug == 0
}

fn test_simple_capture() ? {
    mut p := &Pattern{}
    mut compst := CompileState{ p: p, debug: 0 }

    p.kt.add("test")
    p.tree << TTree{ tag: .tcapture, key: 1 }   // TODO: legacy Lua. index start with 1
    p.tree << TTree{ tag: .tany }
    compst.codegen(0, false, -1, fullset)?
    if compst.debug > 0 { p.code.disassemble(p.kt) }

    assert p.code.len == 4
    assert p.code[0].opcode() == .open_capture
    assert p.code[0].aux() == 1
    assert p.code[1].int() == 0
    assert p.code[2].opcode() == .any
    assert p.code[2].aux() == 0
    assert p.code[3].opcode() == .close_capture

    assert compst.debug == 0
}

fn test_simple_backref() ? {
    mut p := &Pattern{}
    mut compst := CompileState{ p: p, debug: 0 }

    p.tree << TTree{ tag: .tbackref, key: 33 }
    compst.codegen(0, false, -1, fullset)?
    if compst.debug > 0 { p.code.disassemble(p.kt) }

    assert p.code.len == 1
    assert p.code[0].opcode() == .backref
    assert p.code[0].aux() == 33

    assert compst.debug == 0
}

fn test_simple_grammar() ? {
    mut p := &Pattern{}
    mut compst := CompileState{ p: p, debug: 0 }

    p.tree << TTree{ tag: .tgrammar }
    p.tree << TTree{ tag: .trule, ps: 2 }
    p.tree << TTree{ tag: .tany }
    compst.codegen(0, false, -1, fullset)?
    if compst.debug > 0 { p.code.disassemble(p.kt) }

    assert p.code.len == 6
    assert p.code[0].opcode() == .call
    assert p.code[1].int() == 3
    assert p.code[2].opcode() == .jmp
    assert p.code[3].int() == 3
    assert p.code[4].opcode() == .any
    assert p.code[5].opcode() == .ret

    assert compst.debug == 0
}

fn test_simple_call() ? {
    mut p := &Pattern{}
    mut compst := CompileState{ p: p, debug: 0 }

    p.tree << TTree{ tag: .tcall }
    compst.codegen(0, false, -1, fullset)?
    if compst.debug > 0 { p.code.disassemble(p.kt) }

    assert p.code.len == 2
    assert p.code[0].opcode() == .open_call
    assert p.code[0].aux() == 0
    assert p.code[1] == rt.Slot(0)

    assert compst.debug == 0
}

fn test_simple_tseq() ? {
    mut p := &Pattern{}
    mut compst := CompileState{ p: p, debug: 0 }

    p.tree << TTree{ tag: .tseq, ps: 2 }
    p.tree << TTree{ tag: .tany }
    p.tree << TTree{ tag: .tfalse }
    compst.codegen(0, false, -1, fullset)?
    if compst.debug > 0 { p.code.disassemble(p.kt) }

    assert p.code.len == 2
    assert p.code[0].opcode() == .any
    assert p.code[0].aux() == 0
    assert p.code[1].opcode() == .fail
    assert p.code[1].aux() == 0

    assert compst.debug == 0
}

fn test_simple_notree() ? {
    mut p := &Pattern{}
    mut compst := CompileState{ p: p, debug: 0 }

    p.tree << TTree{ tag: .tnotree }
    if _ := compst.codegen(0, false, -1, fullset) { assert false }

    assert compst.debug == 0
}

fn test_simple_runtime() ? {
    mut p := &Pattern{}
    mut compst := CompileState{ p: p, debug: 0 }

    p.tree << TTree{ tag: .truntime }
    if _ := compst.codegen(0, false, -1, fullset) { assert false }

    assert compst.debug == 0
}
/* */