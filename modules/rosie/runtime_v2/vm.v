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
[direct_array_access]
pub fn (mut m Match) vm(start_pc int, start_pos int) bool {
	mut btstack := []BTEntry{ cap: 10 }
	m.add_btentry(mut btstack, pc: m.rplx.code.len)	// end of instructions => return from VM

	// TODO These three vars are exactly what is in BTEntry. We could use BTEntry instead and simplify
	// a bit the btstack.push and pop operations.
	mut pc := start_pc
	mut pos := start_pos
	mut capidx := 0		// Caps are added to a list, but it is a tree. capidx points at the current entry in the list.
	mut fail := false
	mut opcode := Opcode.any

	debug := m.debug
	$if debug {
		if debug > 0 { eprint("\nvm: enter: pc=$pc, pos=$pos, input='$m.input'") }
		defer { if debug > 0 { eprint("\nvm: leave: pc=$pc, pos=$pos") } }
	}

	mut stats := &m.stats
	input := m.input
	code := m.rplx.code
  	for pc < code.len {
		$if debug {
			stats.histogram[opcode].timer.pause()
		}

		instr := code[pc]
		opcode = instr.opcode()

		$if debug {
			if debug > 9 {
				// Note: Seems to be a V-bug: ${m.rplx.instruction_str(pc)} must be last.
				// TODO Replace instruction_str() with repr()
				eprint("\npos: ${pos}, bt.len=${btstack.len}, ${m.rplx.instruction_str(pc)}")
			}

			// Stop the current timer, then determine the new one
			stats.histogram[opcode].count ++
			stats.histogram[opcode].timer.start()

	    	stats.instr_count ++
		}

		eof := pos >= input.len

    	match opcode {
    		.char {
				if eof || input[pos] != instr.ichar() {
					fail = true
				} else {
					pos ++
					pc ++
				}
    		}
    		.choice {	// stack a choice; next fail will jump to 'offset'
				m.add_btentry(mut btstack, capidx: capidx, pc: pc + code[pc + 1], pos: pos)
				pc += 2
    		}
    		.open_capture {		// start a capture (kind is 'aux', key is 'offset')
				capname := m.rplx.symbols.get(instr.aux() - 1)
				level := if m.captures.len == 0 { 0 } else { m.captures[capidx].level + 1 }
      			capidx = m.add_capture(matched: false, name: capname, start_pos: pos, level: level, parent: capidx)
				pc += 2
    		}
    		.test_set {
				if eof || !code.to_charset(pc).testchar(input[pos]) {	// TODO rename to test_set
					pc += code[pc + 1]
					$if debug {
						if debug > 2 { eprint(" => failed: pc=$pc") }
					}
				} else  {
					pc += 1 + 1 + charset_inst_size		// We do this for performance reasons vs. instr.isize()
				}
    		}
    		.test_char {
				if eof || input[pos] != instr.ichar() {
					pc += code[pc + 1]
					$if debug {
						if debug > 2 { eprint(" => failed: pc=$pc") }
					}
				} else {
					pc += 2
				}
    		}
			.any {
      			if eof {
					fail = true
				} else {
					pos ++
					pc ++
				}
    		}
    		.test_any {
      			if eof {
					pc += code[pc + 1]
					$if debug {
						if debug > 2 { eprint(" => failed: pc=$pc") }
					}
				} else {
					pc += 2
				}
    		}
    		.set {
				if !eof && code.to_charset(pc + 1).testchar(input[pos]) {	// TODO rename to test_set
					pos ++
					pc += 1 + charset_inst_size
				} else {
					fail = true
				}
    		}
    		.partial_commit {
				$if debug {
					if debug > 2 { eprint(" '${m.captures[capidx].name}'") }
				}
				btstack.last().pos = pos
				pc += code[pc + 1]
    		}
    		.span {
				// TODO This can probably be optimized
      			for m.testchar(pos, pc + 1) { pos ++ }
				pc += 1 + charset_inst_size
    		}
    		.jmp {
				pc += code[pc + 1]
    		}
			.commit {	// pop a choice; continue at offset
				capidx = btstack.pop().capidx
				pc += code[pc + 1]
				$if debug {
					if debug > 2 { eprint(" => pc=$pc, capidx='${m.captures[capidx].name}'") }
				}
			}
    		.call {		// call rule at 'offset'. Upon failure jmp to X
				pc_next := pc + 1 + code[pc + 2]
				pc_err := pc + 2 + code[pc + 3]
				m.add_btentry(mut btstack, capidx: capidx, pc: pc_err, pc_next: pc_next, pos: pos)
				pc += code[pc + 1]
    		}
    		.back_commit {	// "fails" but jumps to its own 'offset'
				$if debug {
					if debug > 2 { eprint(" '${m.captures[capidx].name}'") }
				}
				x := btstack.pop()
				pos = x.pos
				capidx = x.capidx
				pc += code[pc + 1]
    		}
    		.close_capture {
				$if debug {
					if debug > 2 { eprint(" '${m.captures[capidx].name}'") }
				}
				capidx = m.close_capture(pos, capidx)
				pc ++
    		}
    		.if_char {
				if !eof && input[pos] == instr.ichar() {
					pc += code[pc + 1]
					pos ++
					$if debug {
						if debug > 2 { eprint(" => success: pc=$pc") }
					}
				} else {
					// Char does not match. We do not 'fail', but stay on the current
					// input position and simply continue with the next instruction
					pc += 2
				}
    		}
    		.behind {
				pos -= instr.aux()
				if pos < 0 {
					fail = true
				} else {
					pc ++
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
				$if debug {
					if debug > 2 { eprint(" => pc=$pc, capidx='${m.captures[capidx].name}'") }
				}
    		}
			.word_boundary {
				fail, pos = m.is_word_boundary(pos)
				pc ++
			}
			.dot {
				fail, pos = m.is_dot(pos)
				pc ++
			}
			.until_char {
				for pos < input.len && input[pos] != instr.ichar() {
					pos ++
				}
				pc ++
			}
			.until_set {
				for !m.eof(pos) && m.testchar(pos, pc + 1) == false {
					pos ++
				}
				pc += 1 + charset_inst_size
			}
    		.set_from_to {
				fail = true
				if !eof {
					aux := instr.aux()
					from := aux & 0xff
					to := (aux >> 8) & 0xff
					ch := int(input[pos])
					fail = ch < from || ch > to
				}

				if !fail {
					pos ++
					pc ++
				}
    		}
    		.bit_7 {
				if m.bit_7(pos) {
					fail = true
				} else {
					pos ++
					pc ++
				}
    		}
			.message {
				idx := instr.aux()
				text := m.rplx.symbols.get(idx - 1)
				eprint("\nVM Debug: $text")
				pc ++
			}
    		.end {
				if btstack.len != 1 {
					panic("Expected the VM backtrack stack to have exactly 1 element: $btstack.len")
				}
      			break
    		}
    		.backref {
				// TODO Finding backref is still far too expensive
				name := m.rplx.symbols.get(instr.aux() - 1)	// Get the capture name
				cap := m.find_backref(name, capidx) or {
					panic(err.msg)
				}

				previously_matched_text := cap.text(m.input)
				matched := m.compare_text(pos, previously_matched_text)

				$if debug {
					if debug > 2 {
						eprint(", previously matched text: '$previously_matched_text', success: $matched, input: '${m.input[pos ..]}'")
					}
				}

				if matched {
					pos += previously_matched_text.len
					pc ++
				} else {
					fail = true
				}
    		}
			.register_recursive {
				name := m.rplx.symbols.get(instr.aux() - 1)
				m.recursives << name
				pc ++
			}
    		.halt {		// abnormal end (abort the match)
				break
    		}
			.dbg_level {
				pc ++
			}
		}

		if fail {
			fail = false
			x := btstack.pop()
			pos = x.pos
			pc = x.pc
			capidx = x.capidx
			$if debug {
				if debug > 2 { eprint(" => failed: pc=$pc, capidx='${m.captures[capidx].name}'") }
			}
		}
  	}

	$if debug {
		stats.histogram[opcode].timer.pause()
	}

	if m.captures.len == 0 { panic("Expected to find at least one matched or un-matched Capture") }

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
