module v3

// Opcode These are the byte codes supported by the virtual machine
// Note: Do not change the sequence or re-arrange. The rplx-files with the compiled
// instructions, rely on the integer value for each enum value.
// Note: Only the upper byte must be used for the opcode.
pub enum Opcode {
	any				= 0x0100_0000 // Move input to next char. Fail if end of input data (== eof)
	char 			= 0x0200_0000 // fail if char != aux. Else move input to next char.
	set 			= 0x0300_0000 // fail if char != charset. Else move input to next char.
	span 			= 0x0400_0000 // consume input as long as char matches charset
	test_any 		= 0x0500_0000 // if end of input data (== eof), then jump to 'offset'
	test_char 		= 0x0600_0000 // if char != aux, jump to 'offset'
	test_set 		= 0x0700_0000 // if char not in charset, jump to 'offset'
	choice 			= 0x0800_0000 // stack a choice; next fail will jump to 'offset'
	commit 			= 0x0900_0000 // pop a choice and jump to 'offset'
	fail 			= 0x0A00_0000 // pop a choice, restore the save data, and jump to saved offset
	fail_twice 		= 0x0B00_0000 // pop one choice and then fail (effectively popping 2 choices)
	back_commit 	= 0x0C00_0000 // Same as "fail" but jump to its own 'offset'
	partial_commit 	= 0x0D00_0000 // update top choice to current position and jump to 'offset' (more efficient then a "commit" followed by a "choice")
	jmp 			= 0x0E00_0000 // jump to 'offset'
	call 			= 0x0F00_0000 // call a 'function' at 'offset'. Upon failure jump to 'offset 2'. // TODO Not sure yet this is optimal
	ret 			= 0x1000_0000 // return from a 'function' with 'success' (vs. fail)
	behind 			= 0x1100_0000 // walk back 'aux' characters (fail if not possible)
	backref 		= 0x1200_0000 // match same data as previous capture with 'name' ('aux' is key into symbol table referring to 'name')
	open_capture 	= 0x1300_0000 // start a capture ('offset' is key into symbol table referring to capture 'name')
	close_capture 	= 0x1400_0000 // close current capture (mark as matched) and make its parent capture the new current one
	end 			= 0x1500_0000 // end of pattern (stop execution)
	halt 			= 0x1600_0000 // abnormal end (abort the match)
	// Not present in original Rosie code
	message 		= 0x1700_0000 // Print a (debugging) message
	register_recursive = 0x1800_0000 // Only needed for backref as a stop-point when searching for the back-referenced capture // TODO We need something better / more efficient for resolving back-refs.
	word_boundary 	= 0x1900_0000 // fail if not a word boundary. Else consume all 'spaces' until next word. The VM provides a hard-coded (optimized) instruction, which does exactly the same as the rpl pattern.
	dot 			= 0x1A00_0000 // fail if not matching "." pattern. Else consume the char. The VM provides a hard-coded (optimized) instruction, which does exactly the same as the rpl pattern.
	until_char 		= 0x1B00_0000 // skip all input until it matches the char (used by 'find' macro; eliminating some inefficiencies in the rpl pattern: {{!<pat> .}* <pat>})
	until_set 		= 0x1C00_0000 // skip all input until it matches the charset (used by 'find' macro; eliminating some inefficiencies in the rpl pattern)
	if_char 		= 0x1D00_0000 // if char == aux, jump to 'offset'
	bit_7 			= 0x1E00_0000 // Fail if bit 7 of the input char is set. E.g. [:ascii:] == [x00-x7f] is exactly that. May be it is relevant for other (binary) use cases as well.
	skip_to_newline = 0x1F00_0000 // Skip all input chars until newline ("\r\n", "\n", "\r"). Position will be at the beginning of the next line. // TODO Possible improvement: provide newline char
	str 			= 0x2000_0000 // Same as 'char' and 'set' but for strings
	if_str 			= 0x2100_0000 // Jump if match is successfull
	digit 			= 0x2200_0000 // same [:digit:]
	// skip_char	// implements "\r"?. An optional char. See todos.md
}

// name Determine the name of a byte code instruction
pub fn (op Opcode) name() string {
	return match op {
		.any { "any" }
		.ret { "ret" }
		.end { "end" }
		.halt { "halt" }
		.fail_twice { "fail-twice" }
		.fail { "fail" }
		.close_capture { "close-capture" }
		.behind { "behind" }
		.backref { "backref" }
		.char { "char" }
		.set { "set" }
		.span { "span" }
		.partial_commit { "partial-commit" }
		.test_any { "test-any" }
		.jmp { "jmp" }
		.call { "call" }
		.choice { "choice" }
		.commit { "commit" }
		.back_commit { "back-commit" }
		.open_capture { "open-capture" }
		.test_char { "test-char" }
		.test_set { "test-set" }
		.message { "message" }
		.register_recursive { "register-recursive" }
		.word_boundary { "word-boundary" }
		.dot { "dot" }
		.until_char { "until-char" }
		.until_set { "until-set" }
		.if_char { "if-char" }
		.bit_7 { "bit-7" }
		.skip_to_newline { "skip-to-newline" }
		.str { "str" }
		.if_str { "if_str" }
		.digit { "is-digit" }
	}
}

// Slot Every 'slot' in our byte code is 32 bits
// 'val' can have 1 of 3 meanings, depending on its context
// 1 - 1 x byte opcode and 3 x bytes aux
// 2 - offset: follows an opcode that needs one
type Slot = u32

// TODO rename to hex() ?!?
[inline]
fn (slot Slot) str() string { return "0x${int(slot).hex()}" }

[inline]
fn (slot Slot) int() int { return int(slot) }

// opcode Extract the opcode from the slot (upper 8 bits)
[inline]
fn (slot Slot) opcode() Opcode { return Opcode(slot & 0xff00_0000) }  // TODO How to handle invalid codes ???

// aux Extract the aux value from the slot (upper 24 bits)
[inline]
fn (slot Slot) aux() int { return int(slot) & 0x00ff_ffff }

// ichar Extract the ichar value (== lower 8 bits of the aux value)
[inline]
fn (slot Slot) ichar() byte { return byte(int(slot) & 0xff) }

// sizei Extract the opcode and then determine how many 'slots' the instruction requires
[inline]
fn (slot Slot) sizei() int { return slot.opcode().sizei() }

// sizei Determine how many 'slots' the instruction requires
fn (op Opcode) sizei() int {
	return 2 	// All instructions have a fixed length
}

// opcode_to_slot Convert the opcode into a slot
pub fn opcode_to_slot(oc Opcode) Slot {
	assert u32(oc) >= 0x0100_0000
	return Slot(u32(oc))
}

// set_char Update the slot's 'aux' value with the char and return a new, updated, slot
[inline]
pub fn (slot Slot) set_char(ch byte) Slot { return slot.set_aux(int(ch)) }

// set_aux Update the slot's 'aux' value and return a new, updated, slot
[inline]
pub fn (slot Slot) set_aux(val int) Slot {
	assert (val & 0xff00_0000) == 0
	return Slot(u32(slot) | u32(val))
}

pub fn (rplx Rplx) disassemble() {
	for pc := 0; pc < rplx.code.len; pc += 2 {
		eprintln("  ${rplx.instruction_str(pc)}")
	}
}

// addr The slot following the opcode (== pc) contains an 'offset'.
// Determine the new pc by adding the 'offset' to the pc.
[inline]
pub fn (code []Slot) addr(pc int) int { return pc + int(code[pc + 1]) }

// instruction_str Disassemble the byte code instruction at the program counter
pub fn (rplx Rplx) instruction_str(pc int) string {
	code := rplx.code
	symbols := rplx.symbols
	charsets := rplx.charsets

	instr := code[pc]
	opcode := instr.opcode()
	mut rtn := "pc: ${pc}, ${opcode.name()} "

	match instr.opcode() {
		.any { }
		.ret { }
		.end { }
		.halt { }
		.fail_twice { }
		.fail { }
		.close_capture { }
		.behind { rtn += "revert: -${instr.aux()} chars" }
		.char { rtn += "'${instr.ichar().ascii_str()}'" }
		.set { rtn += charsets[instr.aux()].repr() }
		.span { rtn += charsets[instr.aux()].repr() }
		.partial_commit { rtn += "JMP to ${code.addr(pc)}" }
		.test_any { rtn += "JMP to ${code.addr(pc)}" }
		.jmp { rtn += "to ${code.addr(pc)}" }
		.call { rtn += "JMP to ${code.addr(pc)}" }
		.choice { rtn += "JMP to ${code.addr(pc)}" }
		.commit { rtn += "JMP to ${code.addr(pc)}" }
		.back_commit { }
		.open_capture { rtn += "#${instr.aux()} '${symbols.get(instr.aux())}'" }
		.test_char { rtn += "'${instr.ichar().ascii_str()}' JMP to ${code.addr(pc)}" }
		.test_set { rtn += charsets[instr.aux()].repr() }
		.message { rtn += '${symbols.get(instr.aux())}' }
		.backref { rtn += "'${symbols.get(instr.aux())}'" }
		.register_recursive { rtn += "'${symbols.get(instr.aux())}'" }
		.word_boundary { }
		.dot { }
		.until_char { rtn += "'${instr.ichar().ascii_str()}'" }
		.until_set { rtn += charsets[instr.aux()].repr() }
		.if_char { rtn += "'${instr.ichar().ascii_str()}' JMP to ${code.addr(pc)}" }
		.bit_7 { }
		.skip_to_newline { }
		.str { rtn += "'${symbols.get(instr.aux())}'" }
		.if_str { rtn += "'${symbols.get(instr.aux())}' JMP to ${code.addr(pc)}" }
		.digit { }
	}
	return rtn
}
