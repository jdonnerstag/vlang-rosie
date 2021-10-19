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
	mut bt := BTEntry{ pc: start_pc, pos: start_pos, capidx: 0 }
	mut fail := false
	mut opcode := Opcode.any

	mut stats := &m.stats
	input := m.input
	code := m.rplx.code

	debug := m.debug
	$if debug {
		if debug > 0 { eprint("\nvm: enter: pc=$bt.pc, pos=$bt.pos, input='$input'") }
		defer { if debug > 0 { eprint("\nvm: leave: pc=$bt.pc, pos=$bt.pos") } }
	}

  	for bt.pc < code.len {
		$if debug {
			stats.histogram[opcode].timer.pause()
		}

		instr := code[bt.pc]
		opcode = instr.opcode()
		eof := bt.pos >= input.len
		ch := if eof { 0 } else { input[bt.pos] }

		$if debug {
			if debug > 9 {
				// Note: Seems to be a V-bug: ${m.rplx.instruction_str(pc)} must be last.
				// TODO Replace instruction_str() with repr()
				eprint("\npos: ${bt.pos}, bt.len=${btstack.len}, ${m.rplx.instruction_str(bt.pc)}")
			}

			// Stop the current timer, then determine the new one
			stats.histogram[opcode].count ++
			stats.histogram[opcode].timer.start()

	    	stats.instr_count ++
		}

    	match opcode {
    		.char {
				fail = eof || ch != instr.ichar()
				if !fail {
					bt.pos ++
					bt.pc ++	// We manually (hard-coded) update the PC, rather then isize(), because it is faster
				}
    		}
    		.choice {	// stack a choice; next fail will jump to 'offset'
				pc := bt.pc + code[bt.pc + 1]
				m.add_btentry(mut btstack, capidx: bt.capidx, pc: pc, pos: bt.pos)
				bt.pc += 2
    		}
    		.open_capture {		// start a capture (key is 'offset')
				bt.capidx = m.open_capture(instr, bt)
				bt.pc += 2
    		}
    		.set {
				fail = eof || m.set_instr(instr, ch)
				if !fail {
					bt.pos ++
					bt.pc += 1
				}
    		}
    		.test_set {
				if eof || m.set_instr(instr, ch) {
					bt.pc += code[bt.pc + 1]
					$if debug {
						if debug > 2 { eprint(" => failed: pc=$bt.pc") }
					}
				} else  {
					bt.pc += 2		// We do this for performance reasons vs. instr.isize()
				}
    		}
    		.test_char {
				if eof || ch != instr.ichar() {
					bt.pc += code[bt.pc + 1]
					$if debug {
						if debug > 2 { eprint(" => failed: pc=$bt.pc") }
					}
				} else {
					bt.pc += 2
				}
    		}
			.any {
      			fail = eof
				if !fail {
					bt.pos ++
					bt.pc ++
				}
    		}
    		.test_any {
      			if eof {
					bt.pc += code[bt.pc + 1]
					$if debug {
						if debug > 2 { eprint(" => failed: pc=$bt.pc") }
					}
				} else {
					bt.pc += 2
				}
    		}
    		.partial_commit {
				$if debug {
					if debug > 2 { eprint(" '${m.captures[bt.capidx].name}'") }
				}
				btstack.last().pos = bt.pos
				bt.pc += code[bt.pc + 1]
    		}
    		.span {
				bt.pos = m.span(instr, bt.pos)
				bt.pc += 1
    		}
    		.jmp {
				bt.pc += code[bt.pc + 1]
    		}
			.commit {	// pop a choice; continue at offset
				bt.capidx = btstack.pop().capidx
				bt.pc += code[bt.pc + 1]
				$if debug {
					if debug > 2 { eprint(" => pc=$bt.pc, capidx='${m.captures[bt.capidx].name}'") }
				}
			}
    		.str {
				fail, bt.pos = m.bc_str(instr, bt.pos)
				if !fail { bt.pc ++ }
    		}
    		.if_str {
				fail, bt.pos = m.bc_str(instr, bt.pos)
				if !fail {
					bt.pc += code[bt.pc + 1]
					$if debug {
						if debug > 2 { eprint(" => match: pc=$bt.pc") }
					}
				} else  {
					bt.pc += 2		// We do this for performance reasons vs. instr.isize()
					fail = false	// Reset. if_xxx instructions never 'fail'
				}
    		}
    		.call {		// call rule at 'offset'. Upon failure jmp to X
				m.add_btentry(mut btstack, capidx: bt.capidx, pos: bt.pos, pc: bt.pc + 2)
				bt.pc += code[bt.pc + 1]
    		}
    		.back_commit {	// "fails" but jumps to its own 'offset'
				$if debug {
					if debug > 2 { eprint(" '${m.captures[bt.capidx].name}'") }
				}
				x := btstack.pop()
				bt.pos = x.pos
				bt.capidx = x.capidx
				bt.pc += code[bt.pc + 1]
    		}
    		.close_capture {
				$if debug {
					if debug > 2 { eprint(" '${m.captures[bt.capidx].name}'") }
				}
				bt.capidx = m.close_capture(bt.pos, bt.capidx)
				bt.pc ++
    		}
    		.if_char {
				if !eof && ch == instr.ichar() {
					bt.pc += code[bt.pc + 1]
					bt.pos ++
					$if debug {
						if debug > 2 { eprint(" => success: pc=$bt.pc") }
					}
				} else {
					// Char does not match. We do not 'fail', but stay on the current
					// input position and simply continue with the next instruction
					bt.pc += 2
				}
    		}
    		.behind {
				bt.pos -= instr.aux()
				fail = bt.pos < 0
				if !fail {
					bt.pc ++
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
				btstack.pop()
				x := btstack.pop()
				bt.pc = x.pc
				bt.capidx = x.capidx
				$if debug {
					if debug > 2 { eprint(" => pc=$bt.pc, capidx='${m.captures[bt.capidx].name}'") }
				}
    		}
			.word_boundary {
				if eof {
					bt.pc ++
				} else {
					new_pos := m.is_word_boundary(bt.pos)
					if new_pos == -1 {
						fail = true
					} else {
						bt.pos = new_pos
						bt.pc ++
					}
				}
			}
			.dot {
				fail = eof
				if !fail {
					len := m.is_dot(bt.pos)
					fail = len == 0
					if !fail {
						bt.pos += len
						bt.pc ++
					}
				}
			}
			.until_char {
				bt.pos = m.until_char(instr, bt.pos)
				fail = bt.pos >= input.len
				if !fail {
					bt.pc ++
				}
			}
			.until_set {
				bt.pos = m.until_set(instr, bt.pos)
				fail = bt.pos >= input.len
				if !fail {
					bt.pc ++
				}
			}
    		.set_from_to {
				fail = eof
				if !fail {
					fail = m.set_from_to(instr, ch)
					if !fail {
						bt.pos ++
						bt.pc ++
					}
				}
    		}
    		.bit_7 {
				fail = eof || (ch & 0x80) != 0
				if !fail {
					bt.pos ++
					bt.pc ++
				}
    		}
			.skip_to_newline {
				bt.pos = m.skip_to_newline(bt.pos)
			}
			.message {
				m.message(instr)
				bt.pc ++
			}
    		.backref {
				len := m.backref(instr, bt.pos, bt.capidx)
				fail = len == 0
				if !fail {
					bt.pos += len
					bt.pc ++
				}
    		}
			.register_recursive {
				m.register_recursive(instr)
				bt.pc ++
			}
    		.end {
				if btstack.len != 1 {
					panic("Expected the VM backtrack stack to have exactly 1 element: $btstack.len")
				}
      			break
    		}
    		.halt {		// abnormal end (abort the match)
				break
    		}
		}

		if fail {
			fail = false
			bt = btstack.pop()
			$if debug {
				if debug > 2 { eprint(" => failed: pc=$bt.pc, capidx='${m.captures[bt.capidx].name}'") }
			}
		}
  	}

	$if debug {
		stats.histogram[opcode].timer.pause()
	}

	if m.captures.len == 0 {
		panic("Expected to find at least one matched or un-matched Capture")
	}

	m.matched = m.captures[0].matched
	m.pos = if m.matched { m.captures[0].end_pos } else { start_pos }

	if m.skip_to_newline {
		// m.pos will be updated, even if there was no match
		m.pos = m.skip_to_newline(bt.pos)
	}

	return m.matched
}

// vm_match C
// Can't use match() as "match" is a reserved word in V-lang
// TODO Not sure we need this function going forward. What additional value is it providing?
pub fn (mut m Match) vm_match(input string) bool {
    $if !debug {
        if m.debug > 0 {
			panic("ERROR: Rosie: You must compile the source code with -cg to print the debug messages")
		}
    }

    $if debug {
		if m.debug > 0 { eprint("vm_match: enter (debug=$m.debug)") }

		defer {
			m.stats.match_time.stop()
			if m.debug > 2 {
				eprintln("\nmatched: $m.matched, pos=$m.pos")
				m.print_captures(false)
			}
		}
	}

	m.stats = new_stats()
	m.captures.clear()
	m.input = input
  	return m.vm(0, 0)
}

[direct_array_access]
pub fn (m Match) set_instr(instr Slot, ch byte) bool {
	cs := m.rplx.symbols.get_charset(instr.aux())
	return cs.cmp_char(ch) == false
}

// [inline]
[direct_array_access]
pub fn (mut m Match) span(instr Slot, btpos int) int {
	mut pos := btpos
	cs := m.rplx.symbols.get_charset(instr.aux())
	for pos < m.input.len && cs.cmp_char(m.input[pos]) {
		pos ++
	}
	return pos
}

// [inline]
[direct_array_access]
pub fn (m Match) compare_text(pos int, text string) bool {
	return m.input[pos ..].starts_with(text)
}

// [inline]
[direct_array_access]
pub fn (mut m Match) open_capture(instr Slot, bt BTEntry) int {
	capname := m.rplx.symbols.get(instr.aux())
	level := if m.captures.len == 0 { 0 } else { m.captures[bt.capidx].level + 1 }
	mut cap := Capture{ matched: false, name: capname, start_pos: bt.pos, level: level, parent: bt.capidx }
	$if debug {
		cap.timer.start()
	}

	m.captures << cap
	if m.stats.capture_len < m.captures.len { m.stats.capture_len = m.captures.len }
	return m.captures.len - 1
}

//[inline]
[direct_array_access]
fn (m Match) close_capture(pos int, capidx int) int {
	mut cap := &m.captures[capidx]
	cap.end_pos = pos
	cap.matched = true
	$if debug { cap.timer.stop() }
	if !isnil(m.cap_notification) { m.cap_notification(capidx) }
	return cap.parent
}

//[inline]
fn (mut m Match) add_btentry(mut btstack []BTEntry, entry BTEntry) {
	btstack << entry
	if btstack.len >= 100 { panic("RPL VM stack-overflow?") }
	$if debug {
		if m.stats.backtrack_len < btstack.len { m.stats.backtrack_len = btstack.len }
	}
}

fn (mut m Match) register_recursive(instr Slot) {
	name := m.rplx.symbols.get(instr.aux())
	m.recursives << name
}

fn (m Match) backref(instr Slot, pos int, capidx int) int {
	// TODO Finding backref is still far too expensive
	name := m.rplx.symbols.get(instr.aux())	// Get the capture name
	cap := m.find_backref(name, capidx) or {
		panic(err.msg)
	}

	previously_matched_text := cap.text(m.input)
	matched := m.compare_text(pos, previously_matched_text)

	$if debug {
		if m.debug > 2 {
			eprint(", previously matched text: '$previously_matched_text', success: $matched, input: '${m.input[pos ..]}'")
		}
	}

	if matched {
		return previously_matched_text.len
	}
	return 0
}

fn (m Match) message(instr Slot) {
	idx := instr.aux()
	text := m.rplx.symbols.get(idx)
	eprint("\nVM Debug: $text")
}

fn (m Match) set_from_to(instr Slot, ch byte) bool {
	aux := instr.aux()
	from := aux & 0xff
	to := (aux >> 8) & 0xff
	x := int(ch)
	return x < from || x > to
}

[direct_array_access]
fn (m Match) until_set(instr Slot, btpos int) int {
	mut pos := btpos
	cs := m.rplx.symbols.get_charset(instr.aux())
	for pos < m.input.len && !cs.cmp_char(m.input[pos]) {
		pos ++
	}
	return pos
}

[direct_array_access]
fn (m Match) until_char(instr Slot, btpos int) int {
	ch := instr.ichar()
	mut pos := btpos
	len := m.input.len
	for pos < len && m.input[pos] != ch {
		pos ++
	}
	return pos
}

[direct_array_access]
fn (m Match) bc_str(instr Slot, btpos int) (bool, int) {
	mut pos := btpos
	str := m.rplx.symbols.get(instr.aux())
	len := m.input.len
	for ch in str {
		if pos >= len || m.input[pos] != ch {
			return true, btpos
		}
		pos ++
	}
	return false, pos
}

[direct_array_access]
fn (m Match) is_word_boundary(pos int) int {
	// The boundary symbol, ~, is an ordered choice of:
	//   [:space:]+                   consume all whitespace
	//   { >word_char !<word_char }   looking at a word char, and back at non-word char
	//   >[:punct:] / <[:punct:]      looking at punctuation, or back at punctuation
	//   { <[:space:] ![:space:] }    looking back at space, but not ahead at space
	//   $                            looking at end of input
	//   ^                            looking back at start of input
	// where word_char is the ASCII-only pattern [[A-Z][a-z][0-9]]

	// TODO could this be optimized?
	input := m.input
	mut new_pos := 0
	for new_pos = pos; new_pos < input.len; new_pos++ {
		ch := input[new_pos]
		if ch == 32 { continue }
		if ch >= 9 && ch <= 13 { continue }
		break
	}

	if new_pos > pos {
		return new_pos
	}

	if pos == 0 {
		return pos
	}

	back := input[pos - 1]
	cur := input[pos]
	if cs_alnum.cmp_char(cur) == true && cs_alnum.cmp_char(back) == false {
		return pos
	}
	if cs_punct.cmp_char(cur) == true || cs_punct.cmp_char(back) == true {
		return pos
	}
	if cs_space.cmp_char(back) == true && cs_space.cmp_char(cur) == false {
		return pos
	}

	return -1
}

[direct_array_access]
fn (m Match) is_dot(pos int) int {
	// b1_lead := ascii
	// b2_lead := new_charset_pattern("\300-\337")
	// b3_lead := new_charset_pattern("\340-\357")
	// b4_lead := new_charset_pattern("\360-\367")
	// c_byte := new_charset_pattern("\200-\277")
	//
	// b2 := new_sequence_pattern(false, [b2_lead, c_byte])
	// b3 := new_sequence_pattern(false, [b3_lead, c_byte, c_byte])
	// b4 := new_sequence_pattern(false, [b4_lead, c_byte, c_byte, c_byte])
	//
	// return Pattern{ elem: DisjunctionPattern{ negative: false, ar: [b1_lead, b2, b3, b4] } }

	// TODO There are plenty of articles on how to make this much faster.
	// See e.g. https://lemire.me/blog/2018/05/09/how-quickly-can-you-check-that-a-string-is-valid-unicode-utf-8/

	input := m.input
	b1 := input[pos] or { return 0 }
	if (b1 & 0x80) == 0 { return 1 }

	rest := input.len - pos
	if rest > 1 {
		b2 := input[pos + 1]
		b2_follow := m.is_utf8_follow_byte(b2)

		if b1 >= 0xC2 && b1 <= 0xDF && b2_follow {
			return 2
		}

		if rest > 2 {
			b3 := input[pos + 2]
			b3_follow := m.is_utf8_follow_byte(b3)

			if b1 == 0xE0 && b2 >= 0xA0 && b2 <= 0xBF && b3_follow {
				return 3
			}

			if b1 >= 0xE1 && b1 <= 0xEC && b2_follow && b3_follow {
				return 3
			}

			if b1 == 0xED && b2 >= 0x80 && b2 <= 0x9F && b3_follow {
				return 3
			}

			if b1 >= 0xEE && b1 <= 0xEF && b2_follow && b3_follow {
				return 3
			}

			if rest > 3 {
				b4 := input[pos + 3]
				b4_follow := m.is_utf8_follow_byte(b4)

				if b1 == 0xF0 && b2 >= 0x90 && b2 <= 0xBF && b3_follow && b4_follow {
					return 4
				}

				if b1 >= 0xF1 && b1 <= 0xF3 && b2_follow && b3_follow && b4_follow {
					return 4
				}

				if b1 == 0xF4 && b2_follow && b3_follow && b4_follow {
					return 4
				}
			}
		}
	}

	return 0
}

[inline]
fn (m Match) is_utf8_follow_byte(b byte) bool {
	return b >= 0x80 && b <= 0xBF
}

// skip_to_newline Return the input position following the newline
[direct_array_access]
fn (m Match) skip_to_newline(idx int) int {
	input := m.input
	len := input.len
	mut pos := idx
	for pos < len {
		ch1 := input[pos]
		pos ++

		if ch1 == `\n` { break }
		if ch1 == `\r` {
			if pos < len {
				ch2 := input[pos]
				if ch2 == `\n` {
					pos ++
					break
				}
			}
			break
		}
	}

	return pos
}