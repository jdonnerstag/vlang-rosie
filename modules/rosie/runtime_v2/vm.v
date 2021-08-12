module runtime_v2

// [Rosie](https://rosie-lang.org/) is a pattern language (RPL for short), a little like
// regex, but aiming to solve some of the regex issues and to improve on regex.
//
// This V module implements RPL's runtime which is based on a tiny virtual machine.
// RPL source files (*.rpl) are compile into byte code (*.rplx). The runtime is able
// to read the *.rplx files, exeute the byte code instructions, and thus determine
// the captures when matching input data against the pattern.
//
// Even though this module is able to read *.rplx files, it is not designed to replace
// Rosie's original implementation. The V module does not expose the same libraries
// functions and signatures.
//
// Please note that the *.rplx file structure and neither the byte codes of the virtual
// machine are part of Rosie's specification and thus subject to change without
// formal notice.

import time

// vm This is the main entry point to execute byte code instruction, which
// previously have been loaded.
// - start_pc   Program Counter where to start execution
// - start_pos  Input data index. Where to start the matching process
fn (mut mmatch Match) vm(start_pc int, start_pos int) bool {
	mut btstack := []BTEntry{ cap: 10 }
	mmatch.add_btentry(mut btstack, 0, mmatch.rplx.code.len, 0)	// end of instructions => return from VM

	// TODO These three vars are exactly what is in BTEntry. We could use BTEntry instead and simplify
	// a bit the btstack.push and pop operations.
	mut pc := start_pc
	mut pos := start_pos
	mut capidx := 0		// Caps are added to a list, but it is a tree. capidx points at the current entry in the list.
	mut fail := false

	if mmatch.debug > 0 { eprint("\nvm: enter: pc=$pc, pos=$pos, input='$mmatch.input'") }
	defer { if mmatch.debug > 0 { eprint("\nvm: leave: pc=$pc, pos=$pos") } }

  	for mmatch.has_more_instructions(pc) {
		instr := mmatch.instruction(pc)
    	if mmatch.debug > 9 { eprint("\npos: ${pos}, bt.len=${btstack.len}, ${mmatch.rplx.instruction_str(pc)}") }

    	mmatch.stats.instr_count ++
		opcode := instr.opcode()
    	match opcode {
    		.test_set {
				if !mmatch.testchar(pos, pc + 2) {	// TODO rename to test_set
					pc = mmatch.addr(pc)
					if mmatch.debug > 2 { eprint(" => failed: pc=$pc") }
					continue
				}
    		}
    		.test_char {
				if !mmatch.cmp_char(pos, instr.ichar()) {	// TODO rename to test_char
					pc = mmatch.addr(pc)
					if mmatch.debug > 2 { eprint(" => failed: pc=$pc") }
					continue
				}
    		}
			.any {
      			if !mmatch.eof(pos) {
					pos ++
				} else {
					fail = true
				}
    		}
    		.test_any {
      			if mmatch.eof(pos) {
	      			pc = mmatch.addr(pc)
					if mmatch.debug > 2 { eprint(" => failed: pc=$pc") }
					continue
				}
    		}
    		.char {
				if mmatch.cmp_char(pos, instr.ichar()) {
					pos ++
				} else {
					fail = true
				}
    		}
    		.set {
				if mmatch.testchar(pos, pc + 1) {
					pos ++
				} else {
					fail = true
				}
    		}
    		.partial_commit {
				if mmatch.debug > 2 { eprint(" '${mmatch.captures[capidx].name}'") }
				btstack.last().pos = pos
      			pc = mmatch.addr(pc)
				continue
    		}
    		.span {
      			for mmatch.testchar(pos, pc + 1) { pos ++ }
    		}
    		.jmp {
      			pc = mmatch.addr(pc)
				continue
    		}
    		.choice {	// stack a choice; next fail will jump to 'offset'
				mmatch.add_btentry(mut btstack, capidx, mmatch.addr(pc), pos)
    		}
			.pop_choice {	// pop a choice; continue at offset  // TODO Same as .commit or .ret ?!?
				capidx = btstack.pop().capidx
				pc = mmatch.addr(pc)
				if mmatch.debug > 2 { eprint(" => pc=$pc, capidx='${mmatch.captures[capidx].name}'") }
				continue
			}
			.reset_pos {
				pos = btstack.last().pos
			}
    		.call {		// call rule at 'offset'	// TODO .call and .choice are somewhat redundant ??
				mmatch.add_btentry(mut btstack, capidx, pc + instr.sizei(), pos)
				pc = mmatch.addr(pc)
				continue
    		}
    		.commit {	// pop choice and jump to 'offset'  // TODO should this not include .close_capture?  What is this committing?
				if mmatch.debug > 2 { eprint(" '${mmatch.captures[capidx].name}'") }
				capidx = btstack.pop().capidx
				pc = mmatch.addr(pc)
				continue
    		}
    		.back_commit {	// "fails" but jumps to its own 'offset'
				panic("The 'back_commit' byte code is not implemented")
				if mmatch.debug > 2 { eprint(" '${mmatch.captures[capidx].name}'") }
				x := btstack.pop()
				pos = x.pos
				capidx = x.capidx
				pc = mmatch.addr(pc)
				continue
    		}
    		.close_capture, .close_const_capture {	// push const close capture and index onto cap list
				mut cap := &mmatch.captures[capidx]
				if mmatch.debug > 2 { eprint(" '${cap.name}'") }
				cap.end_pos = pos
				cap.matched = true
				capidx = cap.parent
    		}
    		.open_capture {		// start a capture (kind is 'aux', key is 'offset')
				capname := mmatch.rplx.symbols.get(instr.aux() - 1)
				level := if mmatch.captures.len == 0 { 0 } else { mmatch.captures[capidx].level + 1 }
      			capidx = mmatch.add_capture(capname, pos, level, capidx)
    		}
			.reset_capture {
				mmatch.captures[capidx].start_pos = pos
			}
    		.behind {
				pos -= instr.aux()
				if pos < 0 {
					fail = true
				}
    		}
    		.fail_twice {	// pop one choice from stack and then fail
				btstack.pop()
				fail = true
			}
    		.fail {			// pop stack (pushed on choice), jump to saved offset
				fail = true
      		}
    		.ret {
				x := btstack.pop()
				pc = x.pc
				capidx = x.capidx
				if mmatch.debug > 2 { eprint(" => pc=$pc, capidx='${mmatch.captures[capidx].name}'") }
				continue
    		}
    		.end {
      			break
    		}
    		.backref {	// TODO
				panic("'backref' byte code instruction is not yet implemented")
				_ := mmatch.captures[instr.aux()]
    		}
			.giveup {
				panic("'giveup is not implemented")
			}
    		.halt {		// abnormal end (abort the match)
				break
    		}
			else {
				panic("Illegal opcode at $pc: ${opcode}")
    		}
		}

		if fail {
			fail = false
			x := btstack.pop()
			pos = x.pos
			pc = x.pc
			capidx = x.capidx
			if mmatch.debug > 2 { eprint(" => failed: pc=$pc, capidx='${mmatch.captures[capidx].name}'") }
		} else {
			pc += instr.sizei()
		}
  	}

	if mmatch.captures.len == 0 { panic("Expected to find at least one Capture") }

	mmatch.matched = mmatch.captures[0].matched
	mmatch.pos = if mmatch.matched { mmatch.captures[0].end_pos } else { start_pos }

	return mmatch.matched
}

// vm_match C
// Can't use match() as "match" is a reserved word in V-lang
// TODO Not sure we need this function going forward. What additional value is it providing?
fn (mut mmatch Match) vm_match(input string) bool {
	if mmatch.debug > 0 { eprint("vm_match: enter (debug=$mmatch.debug)") }

	defer {
	  	mmatch.stats.match_time.stop()
		if mmatch.debug > 2 { eprintln("\nmatched: $mmatch.matched, pos=$mmatch.pos, captures: $mmatch.captures") }
	}

	mmatch.stats.match_time = time.new_stopwatch()
	mmatch.input = input
  	return mmatch.vm(0, 0)
}
