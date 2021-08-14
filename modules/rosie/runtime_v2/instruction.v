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
	any				// if no char (eof), then fail
	char           	// if char != aux, fail
	set		     	// if char not in charset, fail
	span		    // read a span of chars in buff  (?? TODO Don't understand the explanation)
	test_any        // if no chars left, jump to 'offset'
	test_char       // if char != aux, jump to 'offset'
	test_set        // if char not in charset, jump to 'offset'
	choice          // stack a choice; next fail will jump to 'offset'
	commit          // pop a choice and jump to 'offset'
	fail           	// pop stack (pushed on choice), jump to saved offset
	fail_twice		// pop one choice from stack and then fail
	back_commit		// "fails" but jumps to its own 'offset'	(?? TODO Don't understand)
	partial_commit  // update top choice to current position and jump
	jmp	         	// jump to 'offset'
	call            // call a "function" at offset. Upon failure jump to X.
	ret				// return from a rule
	behind         	// walk back 'aux' characters (fail if not possible)
	backref			// match same data as prior capture (key is 'aux')
	open_capture	// start a capture (kind is 'aux', key is 'offset')
	close_capture	// push close capture marker onto cap list
	end				// end of pattern (stop execution)
	halt		    // abnormal end (abort the match)
	// Not present in original Rosie code
	reset_pos		// Do not pop the choice stack, but reset pos to the value stored top of the stack (or 0 if empty)
	reset_capture	// Do not pop the capture, but update start_pos to current pos
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
		.reset_pos { "reset-pos" }
		.reset_capture { "reset-capture" }
	}
}

// Slot Every 'slot' in our byte code is 32 bits
// 'val' can have 1 of 3 meanings, depending on its context
// 1 - 1 x byte opcode and 3 x bytes aux
// 2 - offset: follows an opcode that needs one
// 3 - u8: multi-byte char set following an opcode that needs one
// .. in the future there might be more
type Slot = int

[inline]
fn (slot Slot) str() string { return "0x${int(slot).hex()}" }

[inline]
fn (slot Slot) int() int { return int(slot) }

// opcode Given a specific 'slot', determine the byte code
[inline]
fn (slot Slot) opcode() Opcode { return Opcode(slot & 0xff) }  // TODO How to handle invalid codes ???

// aux Given a specific 'slot', determine the aux value
[inline]
fn (slot Slot) aux() int { return (int(slot) >> 8) & 0x00ff_ffff }

// ichar Given a specific 'slot', determine the ichar value
[inline]
fn (slot Slot) ichar() byte { return byte(slot.aux() & 0xff) }

// sizei Determine how many 'slots' are used by an instruction
[inline]
fn (slot Slot) sizei() int { return slot.opcode().sizei() }

fn (op Opcode) sizei() int {
  	match op {
  		.partial_commit, .test_any, .jmp, .choice,
		.commit, .back_commit, .open_capture, .test_char {
	    	return 2
		}
		.call {
	    	return 4
		}
  		.set, .span {
    		return 1 + charset_inst_size
		}
  		.test_set {
    		return 1 + 1 + charset_inst_size
		}
		else {
			return 1
		}
  	}
}

[inline]
pub fn opcode_to_slot(oc Opcode) Slot {
	return Slot(int(oc) & 0xff)
}

[inline]
pub fn (slot Slot) set_char(ch byte) Slot {
	return slot.set_aux(int(ch))
}

[inline]
pub fn (slot Slot) set_aux(val int) Slot {
	assert (val & 0xff00_0000) == 0
	return Slot(int(slot) | (val << 8))
}

[inline]
pub fn opcode_with_char(oc Opcode, c byte) Slot {
    return opcode_to_slot(oc).set_char(c)
}

pub fn (code []Slot) disassemble(symbols Symbols) {
	mut pc := 0
	for pc < code.len {
		eprintln("  ${code.instruction_str(pc, symbols)}")
		pc += code[pc].sizei()
	}
}

[inline]
pub fn (code []Slot) addr(pc int) int { return int(pc + code[pc + 1]) }

pub fn (code []Slot) instruction_str(pc int, symbols Symbols) string {
	instr := code[pc]
	opcode := instr.opcode()
	sz := instr.sizei()
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
		// .backref { return CapKind.backref }
		.char { rtn += "'${instr.ichar().ascii_str()}'" }
		.set { rtn += code.to_charset(pc + 1).repr() }
		.span { rtn += code.to_charset(pc + 1).repr() }
		.partial_commit { rtn += "JMP to ${code.addr(pc)}" }
		.test_any { rtn += "JMP to ${code.addr(pc)}" }
		.jmp { rtn += "to ${code.addr(pc)}" }
		.call { rtn += "JMP to ${code.addr(pc)}, on-rtn=${code.addr(pc + 1)}, on-error=${code.addr(pc + 2)}" }
		.choice { rtn += "JMP to ${code.addr(pc)}" }
		.commit { rtn += "JMP to ${code.addr(pc)}" }
		// .back_commit { }
		.open_capture { rtn += "#${instr.aux()} '${symbols.get(instr.aux() - 1)}'" }
		.test_char { rtn += "'${instr.ichar().ascii_str()}' JMP to ${code.addr(pc)}" }
		.test_set { rtn += code.to_charset(pc + 2).repr() }
		.reset_pos { }
		.reset_capture { }
		else {
			rtn += "aux=${instr.aux()} (0x${instr.aux().hex()})"

			for i in 1 .. sz {
				data := int(code[pc + i])
				rtn += ", $i=${data} (0x${data.hex()})"
			}
		}
	}
	return rtn
}
