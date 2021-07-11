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
	return Slot(int(oc))
}

[inline]
fn (mut slot Slot) set_char(ch byte) {
	slot.set_aux(int(ch))
}

[inline]
fn (mut slot Slot) set_aux(val int) {
	assert (val & 0xff00_0000) == 0
	slot = Slot(int(slot) | (val << 8))
}
