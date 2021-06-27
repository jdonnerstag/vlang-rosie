module disassembler

fn test_print_charset() ? {
    ptr := "1234".str
    assert print_charset(ptr) == "[sssss]"
}
