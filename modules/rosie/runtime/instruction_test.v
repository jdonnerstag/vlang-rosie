module runtime

fn test_opcode_with_char() ? {
	x := opcode_with_char(.char, "a"[0])
	assert x.opcode() == .char
	assert x.ichar() == "a"[0]
}