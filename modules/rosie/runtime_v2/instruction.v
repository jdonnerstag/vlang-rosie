module runtime_v2

/* The below comments are from the original rosie C-code. Not sure how much
   they are relevant for the V implementation as well.

  Most common instructions (totaling 98%):
  ITestSet offset, charset
  IAny
  IPartialCommit offset

 Reference:
  unsigned 16-bit (short) 65,536
  signed 24-bit        8,388,607
  unsigned 24-bit     16,777,216
  signed int32     2,147,483,647  (2Gb)
  uint32_t         4,294,967,296  (4Gb)

 TESTS show that accessing the 24-bit field as a signed or unsigned
 int takes time indistinguishable from accessing a 32-bit int value.
 Storing the 24-bit value takes significantly longer (> 2x) than
 storing a 32-bit int, but we only store the symbols index when we
 are compiling, not at runtime in the vm.

 Desirable:
   Byte-addressable input data up to 4Gb (affects runtime & output encoding, not instruction coding)
   Symbols as large as 8M elements, at least
   Instructions in compilation unit at least 1M (= 20 bits, ==> 21 bits offset)
   Room for many new instructions, particularly multi-char ones
   Room for more capture kinds, at least 6 bits' worth
*/

// Opcode These are the byte codes supported by the virtual machine
// Note: Do not change the sequence or re-arrange. The original rplx-files with the compiled
// instructions, rely on the (auto-assigned) integer value for each enum value.
pub enum Opcode {
	any				// Move input to next char. Fail if end of input data (== eof)
	char           	// fail if char != aux. Else move input to next char.
	set		     	// fail if char != charset. Else move input to next char.
	span		    // consume input as long as char matches charset
	test_any        // if end of input data (== eof), then jump to 'offset'
	test_char       // if char != aux, jump to 'offset'
	test_set        // if char not in charset, jump to 'offset'
	choice          // stack a choice; next fail will jump to 'offset'
	commit          // pop a choice and jump to 'offset'
	fail           	// pop a choice, restore the save data, and jump to saved offset
	fail_twice		// pop one choice and then fail (effectively popping 2 choices)
	back_commit		// Same as "fail" but jump to its own 'offset'
	partial_commit  // update top choice to current position and jump to 'offset' (more efficient then a "commit" followed by a "choice")
	jmp	         	// jump to 'offset'
	call            // call a 'function' at 'offset'. Upon failure jump to 'offset 2'. // TODO Not sure yet this is optimal
	ret				// return from a 'function' with 'success' (vs. fail)
	behind         	// walk back 'aux' characters (fail if not possible)
	backref			// match same data as previous capture with 'name' ('aux' is key into symbol table referring to 'name')
	open_capture	// start a capture ('offset' is key into symbol table referring to capture 'name')
	close_capture	// close current capture (mark as matched) and make its parent capture the new current one
	end				// end of pattern (stop execution)
	halt		    // abnormal end (abort the match)
	// Not present in original Rosie code
	message			// Print a (debugging) message
	register_recursive	// Only needed for backref as a stop-point when searching for the back-referenced capture // TODO We need something better / more efficient for resolving back-refs.
	word_boundary	// fail if not a word boundary. Else consume all 'spaces' until next word. The VM provides a hard-coded (optimized) instruction, which does exactly the same as the rpl pattern.
	dot				// fail if not matching "." pattern. Else consume the char. The VM provides a hard-coded (optimized) instruction, which does exactly the same as the rpl pattern.
	until_char		// skip all input until it matches the char (used by 'find' macro; eliminating some inefficiencies in the rpl pattern: {{!<pat> .}* <pat>})
	until_set		// skip all input until it matches the charset (used by 'find' macro; eliminating some inefficiencies in the rpl pattern)
	if_char			// if char == aux, jump to 'offset'
	bit_7			// Fail if bit 7 of the input char is set. E.g. [:ascii:] == [x00-x7f] is exactly that. May be it is relevant for other (binary) use cases as well.
	skip_to_newline	// Skip all input chars until newline ("\r\n", "\n", "\r"). Position will be at the beginning of the next line. // TODO Possible improvement: provide newline char
	str				// Same as 'char' and 'set' but for strings
	if_str			// Jump if match is successfull
	digit			// same [:digit:]
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
// 3 - u8: multi-bytechar set following an opcode that needs one
// .. in the future there might be more
type Slot = int

// TODO rename to hex() ?!?
[inline]
fn (slot Slot) str() string { return "0x${int(slot).hex()}" }

[inline]
fn (slot Slot) int() int { return int(slot) }

// opcode Extract the opcode from the slot (lower 8 bits)
[inline]
fn (slot Slot) opcode() Opcode { return Opcode(slot & 0xff) }  // TODO How to handle invalid codes ???

// aux Extract the aux value from the slot (upper 24 bits)
[inline]
fn (slot Slot) aux() int { return (int(slot) >> 8) & 0x00ff_ffff }

// ichar Extract the ichar value (== lower 8 bits of the aux value)
[inline]
fn (slot Slot) ichar() byte { return byte((int(slot) >> 8) & 0xff) }

// sizei Extract the opcode and then determine how many 'slots' the instruction requires
[inline]
fn (slot Slot) sizei() int { return slot.opcode().sizei() }

// sizei Determine how many 'slots' the instruction requires
fn (op Opcode) sizei() int {
	return 2 // All instructions have a fixed length
/*
	match op {
		.partial_commit, .test_any, .jmp, .choice, .commit, .back_commit,
		.open_capture, .test_char, .if_char, .test_set, .if_str, .call {
			return 2
		}
		else {
			return 1
		}
	}
*/
}

// opcode_to_slot Convert the opcode into a slot
[inline]
pub fn opcode_to_slot(oc Opcode) Slot { return Slot(int(oc) & 0xff) }

// set_char Update the slot's 'aux' value with the char and return a new, updated, slot
[inline]
pub fn (slot Slot) set_char(ch byte) Slot { return slot.set_aux(int(ch)) }

// set_aux Update the slot's 'aux' value and return a new, updated, slot
[inline]
pub fn (slot Slot) set_aux(val int) Slot {
	assert (val & 0xff00_0000) == 0
	return Slot(int(slot) | (val << 8))
}

pub fn (rplx Rplx) disassemble() {
	for pc := 0; pc < rplx.code.len; pc += 2 {
		eprintln("  ${rplx.instruction_str(pc)}")
	}
}

// addr The slot following the opcode (== pc) contains an 'offset'.
// Determine the new pc by adding the 'offset' to the pc.
[inline]
pub fn (code []Slot) addr(pc int) int { return int(pc + code[pc + 1]) }

// TODO Replace with repr() to be consistent across the project ??
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
