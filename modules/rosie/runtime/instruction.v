module runtime

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
 storing a 32-bit int, but we only store the ktable index when we
 are compiling, not at runtime in the vm.

 Desirable:
   Byte-addressable input data up to 4Gb (affects runtime & output encoding, not instruction coding)
   Ktable as large as 8M elements, at least
   Instructions in compilation unit at least 1M (= 20 bits, ==> 21 bits offset)
   Room for many new instructions, particularly multi-char ones
   Room for more capture kinds, at least 6 bits' worth
*/

// Opcode These are the byte codes supported by the virtual machine
pub enum Opcode {
	// Bare instruction ------------------------------------------------------------
	giveup			// for internal use by the vm
	any				// if no char, fail
	ret				// return from a rule
	end				// end of pattern
	halt		    // abnormal end (abort the match)
	fail_twice		// pop one choice from stack and then fail
	fail           	// pop stack (pushed on choice), jump to saved offset
	close_capture	// push close capture marker onto cap list
	// Aux -------------------------------------------------------------------------
	behind         	// walk back 'aux' characters (fail if not possible)
	backref			// match same data as prior capture (key is 'aux')
	char           	// if char != aux, fail
	close_const_capture  // push const close capture and index onto cap list
	// Charset ---------------------------------------------------------------------
	set		     	// if char not in buff, fail
	span		    // read a span of chars in buff
	// Offset ----------------------------------------------------------------------
	partial_commit  // update top choice to current position and jump
	test_any        // if no chars left, jump to 'offset'
	jmp	         	// jump to 'offset'
	call            // call rule at 'offset'
	open_call       // call rule number 'key' (must be closed to a ICall)
	choice          // stack a choice; next fail will jump to 'offset'
	commit          // pop choice and jump to 'offset'
	back_commit		// "fails" but jumps to its own 'offset'
	// Offset and aux --------------------------------------------------------------
	open_capture	// start a capture (kind is 'aux', key is 'offset')
	test_char       // if char != aux, jump to 'offset'
	// Offset and charset ----------------------------------------------------------
	test_set        // if char not in buff, jump to 'offset'
	// Offset and aux and charset --------------------------------------------------
	// none (so far)
}

// name Determine the name of a byte code instruction
pub fn (op Opcode) name() string {
	return match op {
		.giveup { "giveup" }
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
		.close_const_capture { "close-const-capture" }
		.set { "set" }
		.span { "span" }
		.partial_commit { "partial-commit" }
		.test_any { "test-any" }
		.jmp { "jmp" }
		.call { "call" }
		.open_call { "open-call" }
		.choice { "choice" }
		.commit { "commit" }
		.back_commit { "back-commit" }
		.open_capture { "open-capture" }
		.test_char { "test-char" }
		.test_set { "test-set" }
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
  		.partial_commit, .test_any, .jmp, .call, .open_call, .choice,
		.commit, .back_commit, .open_capture, .test_char {
	    	return 2
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

pub fn (code []Slot) disassemble(ktable Ktable) {
	mut pc := 0
	for pc < code.len {
		eprintln("  ${code.instruction_str(pc, ktable)}")
		pc += code[pc].sizei()
	}
}

[inline]
pub fn (code []Slot) addr(pc int) int { return int(pc + code[pc + 1]) }

pub fn (code []Slot) instruction_str(pc int, ktable Ktable) string {
	instr := code[pc]
	opcode := instr.opcode()
	sz := instr.sizei()
	mut rtn := "pc: ${pc}, ${opcode.name()} "

	match instr.opcode() {
		.giveup { }
		// .any { }
		.ret { }
		.end { }
		// .halt { }
		.fail_twice { }
		.fail { }
		.close_capture { }
		// .behind { }
		// .backref { return CapKind.backref }
		.char { rtn += "'${instr.ichar().ascii_str()}'" }
		// .close_const_capture { return CapKind.close_const }
		.set { rtn += code.to_charset(pc + 2).str() }
		.span { rtn += code.to_charset(pc + 1).str() }
		.partial_commit { rtn += "JMP to ${code.addr(pc)}" }
		// .test_any { }
		.jmp { rtn += "to ${code.addr(pc)}" }
		.call { rtn += "JMP to ${code.addr(pc)}" }
		// .open_call { }
		.choice { rtn += "JMP to ${code.addr(pc)}" }
		.commit { rtn += "JMP to ${code.addr(pc)}" }
		// .back_commit { }
		.open_capture { rtn += "#${int(code[pc + 1])} '${ktable.get(int(code[pc + 1]) - 1)}'" }
		.test_char { rtn += "'${instr.ichar().ascii_str()}' JMP to ${code.addr(pc)}" }
		.test_set { rtn += code.to_charset(pc + 2).str() }
		.any { }
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

pub fn (mut code []Slot) add_open_capture(idx int) int {
	rtn := code.len
	code << opcode_to_slot(.open_capture)
	code << Slot(idx + 1)		// TODO orig Lua code is using 1-based indexes
	return rtn
}

pub fn (mut code []Slot) add_close_capture() int {
	rtn := code.len
	code << opcode_to_slot(.close_capture)
	return rtn
}

pub fn (mut code []Slot) add_end() int {
	rtn := code.len
	code << opcode_to_slot(.end)
	return rtn
}

pub fn (mut code []Slot) add_char(ch byte) int {
	rtn := code.len
	code << opcode_to_slot(.char).set_char(ch)
	return rtn
}

pub fn (mut code []Slot) add_span(cs Charset) int {
	rtn := code.len
	code << opcode_to_slot(.span)
	for i in 0 .. charset_inst_size {
		code << cs.data[i]
	}
	return rtn
}

pub fn (mut code []Slot) add_test_char(ch byte, pos int) int {
	rtn := code.len
	code << opcode_to_slot(.test_char).set_char(ch)
	code << pos - rtn + 2
	return rtn
}

pub fn (mut code []Slot) add_choice(pos int) int {
	rtn := code.len
	code << opcode_to_slot(.choice)
	code << pos - rtn + 2
	return rtn
}

pub fn (mut code []Slot) add_partial_commit(pos int) int {
	rtn := code.len
	code << opcode_to_slot(.partial_commit)
	code << pos - rtn
	return rtn
}

pub fn (mut code []Slot) add_any() int {
	rtn := code.len
	code << opcode_to_slot(.any)
	return rtn
}

pub fn (mut code []Slot) add_commit(pos int) int {
	rtn := code.len
	code << opcode_to_slot(.commit)
	code << pos - rtn + 2
	return rtn
}

pub fn (mut code []Slot) update_addr(pc int, pos int) {
	code[pc + 1] = pos - pc + 2
}
