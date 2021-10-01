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

// vm This is the main entry point to execute byte code instruction, which
// previously have been loaded.
// - start_pc   Program Counter where to start execution
// - start_pos  Input data index. Where to start the matching process
fn (mut m Match) vm(start_pc int, start_pos int) bool {
	mut btstack := []BTEntry{ cap: 10 }
	m.add_btentry(mut btstack, pc: m.rplx.code.len)	// end of instructions => return from VM

	// TODO These three vars are exactly what is in BTEntry. We could use BTEntry instead and simplify
	// a bit the btstack.push and pop operations.
	mut pc := start_pc
	mut pos := start_pos
	mut capidx := 0		// Caps are added to a list, but it is a tree. capidx points at the current entry in the list.
	mut fail := false

	if m.debug > 0 { eprint("\nvm: enter: pc=$pc, pos=$pos, input='$m.input'") }
	defer { if m.debug > 0 { eprint("\nvm: leave: pc=$pc, pos=$pos") } }

  	for m.has_more_instructions(pc) {
		instr := m.instruction(pc)
    	if m.debug > 9 {
			// Note: Seems to be a V-bug: ${m.rplx.instruction_str(pc)} must be last.
			eprint("\npos: ${pos}, bt.len=${btstack.len}, ${m.rplx.instruction_str(pc)}")
		}

    	m.stats.instr_count ++
		opcode := instr.opcode()
    	match opcode {
    		.test_set {
				if !m.testchar(pos, pc + 2) {	// TODO rename to test_set
					pc = m.addr(pc)
					if m.debug > 2 { eprint(" => failed: pc=$pc") }
					continue
				}
    		}
    		.test_char {
				if !m.cmp_char(pos, instr.ichar()) {	// TODO rename to test_char
					pc = m.addr(pc)
					if m.debug > 2 { eprint(" => failed: pc=$pc") }
					continue
				}
    		}
			.any {
      			if !m.eof(pos) {
					pos ++
				} else {
					fail = true
				}
    		}
    		.test_any {
      			if m.eof(pos) {
	      			pc = m.addr(pc)
					if m.debug > 2 { eprint(" => failed: pc=$pc") }
					continue
				}
    		}
    		.char {
				if m.cmp_char(pos, instr.ichar()) {
					pos ++
				} else {
					fail = true
				}
    		}
    		.set {
				if m.testchar(pos, pc + 1) {
					pos ++
				} else {
					fail = true
				}
    		}
    		.partial_commit {
				if m.debug > 2 { eprint(" '${m.captures[capidx].name}'") }
				btstack.last().pos = pos
      			pc = m.addr(pc)
				continue
    		}
    		.span {
      			for m.testchar(pos, pc + 1) { pos ++ }
    		}
    		.jmp {
      			pc = m.addr(pc)
				continue
    		}
    		.choice {	// stack a choice; next fail will jump to 'offset'
				m.add_btentry(mut btstack, capidx: capidx, pc: m.addr(pc), pos: pos)
    		}
			.commit {	// pop a choice; continue at offset
				capidx = btstack.pop().capidx
				pc = m.addr(pc)
				if m.debug > 2 { eprint(" => pc=$pc, capidx='${m.captures[capidx].name}'") }
				continue
			}
    		.call {		// call rule at 'offset'. Upon failure jmp to X
				pc_next := m.addr(pc + 1)
				pc_err := m.addr(pc + 2)
				m.add_btentry(mut btstack, capidx: capidx, pc: pc_err, pc_next: pc_next, pos: pos)
				pc = m.addr(pc)
				continue
    		}
    		.back_commit {	// "fails" but jumps to its own 'offset'
				if m.debug > 2 { eprint(" '${m.captures[capidx].name}'") }
				x := btstack.pop()
				pos = x.pos
				capidx = x.capidx
				pc = m.addr(pc)
				continue
    		}
    		.close_capture {
				if m.debug > 2 { eprint(" '${m.captures[capidx].name}'") }
				capidx = m.close_capture(pos, capidx)
    		}
    		.open_capture {		// start a capture (kind is 'aux', key is 'offset')
				capname := m.rplx.symbols.get(instr.aux() - 1)
				level := if m.captures.len == 0 { 0 } else { m.captures[capidx].level + 1 }
      			capidx = m.add_capture(matched: false, name: capname, start_pos: pos, level: level, parent: capidx)
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
				pc = x.pc_next
				capidx = x.capidx
				if m.debug > 2 { eprint(" => pc=$pc, capidx='${m.captures[capidx].name}'") }
				continue
    		}
			.word_boundary {
				fail, pos = m.is_word_boundary(pos)
			}
			.dot {
				fail, pos = m.is_dot(pos)
			}
			.until_char {
				for !m.eof(pos) && m.cmp_char(pos, instr.ichar()) == false {
					pos ++
				}
			}
			.until_set {
				for !m.eof(pos) && m.testchar(pos, pc + 1) == false {
					pos ++
				}
			}
    		.if_char {
				if m.cmp_char(pos, instr.ichar()) {
					pc = m.addr(pc)
					pos ++
					if m.debug > 2 { eprint(" => success: pc=$pc") }
					continue
				} else {
					// Char does not match. We do not 'fail', but stay on the current
					// input position and simply continue with the next instruction
				}
    		}
    		.bit_7 {
				if m.bit_7(pos) {
					fail = true
				} else {
					pos ++
				}
    		}
			.message {
				idx := instr.aux()
				text := m.rplx.symbols.get(idx - 1)
				eprint("\nVM Debug: $text")
			}
    		.end {
				if btstack.len != 1 { panic("Expected the VM backtrack stack to have exactly 1 element: $btstack.len") }
      			break
    		}
    		.backref {
				name := m.rplx.symbols.get(instr.aux() - 1)	// Get the capture name
				cap := m.find_backref(name, capidx) or {
					panic(err.msg)
				}

				previously_matched_text := cap.text(m.input)
				matched := m.compare_text(pos, previously_matched_text)
				if m.debug > 2 {
					eprint(", previously matched text: '$previously_matched_text', success: $matched, input: '${m.input[pos ..]}'")
				}

				if matched {
					pos += previously_matched_text.len
				} else {
					fail = true
				}
    		}
			.register_recursive {
				name := m.rplx.symbols.get(instr.aux() - 1)
				m.recursives << name
			}
    		.halt {		// abnormal end (abort the match)
				break
    		}
			.dbg_level {
				// nothing
			}
		}

		if fail {
			fail = false
			x := btstack.pop()
			pos = x.pos
			pc = x.pc
			/*
			if capidx > x.capidx {
				//eprintln("Captures: " + ' '.repeat(40))
				lb := m.captures.len
				// TODO We needs something faster. Maintain the last idx of true and truncate?
				for m.captures.len > (x.capidx + 1) && m.captures.last().matched == false {
					m.captures.pop()
				}
				//eprintln("capidx: $capidx, x.capidx: $x.capidx, lb: $lb, ln: $m.captures.len")
				// TODO Even with this, we are creating far too many captures
			}
			*/
			capidx = x.capidx
			if m.debug > 2 { eprint(" => failed: pc=$pc, capidx='${m.captures[capidx].name}'") }
		} else {
			pc += instr.sizei()
		}
  	}

	if m.captures.len == 0 { panic("Expected to find at least one Capture") }

	m.matched = m.captures[0].matched
	m.pos = if m.matched { m.captures[0].end_pos } else { start_pos }

	return m.matched
}

// vm_match C
// Can't use match() as "match" is a reserved word in V-lang
// TODO Not sure we need this function going forward. What additional value is it providing?
pub fn (mut m Match) vm_match(input string) bool {
	if m.debug > 0 { eprint("vm_match: enter (debug=$m.debug)") }

	defer {
	  	m.stats.match_time.stop()
		if m.debug > 2 { eprintln("\nmatched: $m.matched, pos=$m.pos, captures: $m.captures") }
	}

	m.stats = new_stats()
	m.captures.clear()
	m.input = input
  	return m.vm(0, 0)
}

pub fn (m Match) compare_text(pos int, text string) bool {
	return m.input[pos ..].starts_with(text)
}
