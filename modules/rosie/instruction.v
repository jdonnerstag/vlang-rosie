module rosie

// Most common instructions (totaling 98%):
//   ITestSet offset, charset
//   IAny
//   IPartialCommit offset

// Reference:
//  unsigned 16-bit (short) 65,536
//  signed 24-bit        8,388,607  
//  unsigned 24-bit     16,777,216
//  signed int32     2,147,483,647  (2Gb)
//  uint32_t         4,294,967,296  (4Gb)

// TESTS show that accessing the 24-bit field as a signed or unsigned
// int takes time indistinguishable from accessing a 32-bit int value.
// Storing the 24-bit value takes significantly longer (> 2x) than
// storing a 32-bit int, but we only store the ktable index when we
// are compiling, not at runtime in the vm.

/* Desirable:
 *   Byte-addressable input data up to 4Gb (affects runtime & output encoding, not instruction coding)
 *   Ktable as large as 8M elements, at least
 *   Instructions in compilation unit at least 1M (= 20 bits, ==> 21 bits offset)
 *   Room for many new instructions, particularly multi-char ones
 *   Room for more capture kinds, at least 6 bits' worth
 */
enum Opcode {
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

// TODO Does V maybe provide a name() function already?
fn (op Opcode) name() string {
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

pub struct Instruction {
pub mut:
	val int			
	// 'val' can have 1 of 3 meanings, depending on its context
	// 1 - 1 x byte qcode and 3 x bytes aux
	// 2 - offset: follows an opcode that needs one
	// 3 - u8: char set following an opcode that needs one
}

[inline]
fn new_opcode_instruction(op Opcode) Instruction {
	return Instruction{ val: int(op) }
}

[inline]
fn (instr Instruction) qcode() int { return instr.val & 0xff }

[inline]
fn (instr Instruction) opcode() Opcode { return Opcode(instr.qcode()) }  // TODO How to handle invalid codes ???

[inline]
fn (instr Instruction) aux() int { return (instr.val >> 8) & 0x00ff_ffff }

[inline]
fn (instr Instruction) ichar() byte { return byte(instr.aux() & 0xff) }

// capidx Capture Index
[inline]
fn (instr Instruction) capidx() int { return instr.aux() }

[inline]
fn (mut instr Instruction) setcapidx(newidx int) { 
	assert (newidx & 0xff00_0000) == 0
	instr.val = newidx 
}

// Size of an instruction
fn (instr Instruction) sizei() int {
  	match instr.opcode() {
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
