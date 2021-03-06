module v2

import time
import rosie

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
	mut btstack := m.btstack	// Note: this creates a mutable copy of the array and not just a reference
	mut btidx := m.btidx

	mut bt := BTEntry{ pc: start_pc, pos: start_pos, capidx: m.capidx }
	mut fail := false
	mut idx := int((u32(Opcode.any) >> 24) & 0xff)
	mut timer := &m.stats.histogram[idx].timer
	mut instr_count := 0

	input := m.input
	code := m.rplx.code
	keep_all_captures := m.keep_all_captures

	debug := m.debug
	$if debug {
		if debug > 0 {
			eprint("\nvm: enter: pc=$bt.pc, pos=$bt.pos, btidx=$btidx, capidx=$bt.capidx, cap.len=$m.captures.len, input='$input'")
		}

		defer {
			if debug > 0 {
				eprint("\nvm: leave: pc=$bt.pc, pos=$bt.pos, btidx=$m.btidx, capidx=$m.capidx, cap.len=$m.captures.len")
			}
		}
	}

	for bt.pc < code.len {
		$if debug {
			timer.pause()
		}

		instr_count ++
		instr := code[bt.pc]
		opcode := instr.opcode()
		eof := bt.pos >= input.len

		$if debug {
			if debug > 9 {
				// Note: Seems to be a V-bug: ${m.rplx.instruction_str(pc)} must be last.
				// TODO Replace instruction_str() with repr()
				eprint("\npos: ${bt.pos}, btidx=${btidx}, caplen=${m.captures.len}, ${m.rplx.instruction_str(bt.pc)}")
			}

			idx = int((u32(opcode) >> 24) & 0xff)
			m.stats.histogram[idx].count ++

			// Stop the current timer, then determine the new one
			timer = &m.stats.histogram[idx].timer
			timer.start()
		}

		match opcode {
			.char {
				fail = eof || input[bt.pos] != instr.ichar()
				if !fail { bt.pos ++ }
			}
			.choice {	// stack a choice; next fail will jump to 'offset'
				btidx ++
				btstack[btidx] = BTEntry{ capidx: bt.capidx, pc: m.jmp_addr(bt.pc), pos: bt.pos }
				m.add_btentry(btidx)	// end of instructions => return from VM
			}
			.open_capture {		// start a capture (key is 'offset')
				bt.capidx = m.open_capture(instr, bt)
			}
			.set {
				fail = eof || m.set_instr(instr, input[bt.pos])
				if !fail { bt.pos ++ }
			}
			.test_set {
				if eof || m.set_instr(instr, input[bt.pos]) {
					bt.pc = m.jmp_addr(bt.pc)
					$if debug {
						if debug > 2 { eprint(" => failed: pc=$bt.pc") }
					}
					continue
				}
			}
			.test_char {
				if eof || input[bt.pos] != instr.ichar() {
					bt.pc = m.jmp_addr(bt.pc)
					$if debug {
						if debug > 2 { eprint(" => failed: pc=$bt.pc") }
					}
					continue
				}
			}
			.any {
	  			fail = eof
				if !fail { bt.pos ++ }
			}
			.test_any {
	  			if eof {
					bt.pc = m.jmp_addr(bt.pc)
					$if debug {
						if debug > 2 { eprint(" => failed: pc=$bt.pc") }
					}
					continue
				}
			}
			.digit {
				fail = eof || input[bt.pos] < 48 || input[bt.pos] > 57
				if !fail { bt.pos ++ }
			}
			.partial_commit {
				$if debug {
					if debug > 2 { eprint(" '${m.get_capture_name_idx(bt.capidx)}'") }
				}
				btstack[btidx].pos = bt.pos
				bt.pc = m.jmp_addr(bt.pc)
				continue
			}
			.span {
				bt.pos = m.span(instr, bt.pos)
			}
			.jmp {
				bt.pc = m.jmp_addr(bt.pc)
				continue
			}
			.commit {	// pop a choice; continue at offset
				bt.capidx = btstack[btidx].capidx
				btidx --
				bt.pc = m.jmp_addr(bt.pc)
				$if debug {
					if debug > 2 { eprint(" => pc=$bt.pc, capidx='${m.get_capture_name_idx(bt.capidx)}'") }
				}
				continue
			}
			.str {
				fail, bt.pos = m.bc_str(instr, bt.pos)
			}
			.if_str {
				fail, bt.pos = m.bc_str(instr, bt.pos)
				if !fail {
					bt.pc = m.jmp_addr(bt.pc)
					$if debug {
						if debug > 2 { eprint(" => match: pc=$bt.pc") }
					}
					continue
				}
				fail = false	// Reset. if_xxx instructions never 'fail'
			}
			.call {		// call rule at 'offset'. Upon failure jmp to X
				btidx ++
				btstack[btidx] = BTEntry{ capidx: bt.capidx, pos: bt.pos, pc: bt.pc + 2 }
				m.add_btentry(btidx)
				bt.pc = m.jmp_addr(bt.pc)
				continue
			}
			.back_commit {	// "fails" but jumps to its own 'offset'
				$if debug {
					if debug > 2 { eprint(" '${m.get_capture_name_idx(bt.capidx)}'") }
				}
				bt.pos = btstack[btidx].pos
				bt.capidx = btstack[btidx].capidx
				btidx --
				bt.pc = m.jmp_addr(bt.pc)
				continue
			}
			.close_capture {
				$if debug {
					if debug > 2 { eprint(" '${m.get_capture_name_idx(bt.capidx)}'") }
				}
				bt.capidx = m.close_capture(bt.pos, bt.capidx)
			}
			.if_char {
				if !eof && input[bt.pos] == instr.ichar() {
					bt.pc = m.jmp_addr(bt.pc)
					bt.pos ++
					$if debug {
						if debug > 2 { eprint(" => success: pc=$bt.pc") }
					}
					continue
				}
			}
			.behind {
				bt.pos -= instr.aux()
				fail = bt.pos < 0
			}
			.fail_twice {	// pop one choice from stack and then fail
				btidx --
				fail = true
			}
			.fail {			// pop stack (pushed on choice), jump to saved offset
				fail = true
	  		}
			.ret {
				btidx --
				bt.pc = btstack[btidx].pc
				bt.capidx = btstack[btidx].capidx
				btidx --
				$if debug {
					if debug > 2 { eprint(" => pc=$bt.pc, capidx='${m.get_capture_name_idx(bt.capidx)}'") }
				}
				continue
			}
			.word_boundary {
				if !eof {
					new_pos := m.is_word_boundary(bt.pos)
					fail = new_pos == -1
					if !fail { bt.pos = new_pos }
				}
			}
			.dot {
				fail = eof
				if !fail {
					len := m.is_dot(bt.pos)
					fail = len == 0
					if !fail { bt.pos += len }
				}
			}
			.until_char {
				mode := code[bt.pc + 1]
				bt.pos = m.until_char(instr, bt.pos)
				if bt.pos >= input.len {
					fail = mode == 0 	// Mode 1: find and fail if not found. Stop at match.
				} else if mode != 0 {	// Mode 2: never fail. Either match or end of file. Stop at next char.
					bt.pos ++
				}
			}
			.until_set {
				mode := code[bt.pc + 1]
				bt.pos = m.until_set(instr, bt.pos)
				if bt.pos >= input.len {
					fail = mode == 0 	// Mode 1: find and fail if not found. Stop at match.
				} else if mode != 0 {	// Mode 2: never fail. Either match or end of file. Stop at next char.
					bt.pos ++
				}
			}
			.bit_7 {
				fail = eof || (input[bt.pos] & 0x80) != 0
				if !fail { bt.pos ++ }
			}
			.message {
				m.message(instr)
			}
			.backref {
				len := m.backref(instr, bt.pos, bt.capidx)
				fail = len == 0
				if !fail { bt.pos += len }
			}
			.register_recursive {
				m.register_recursive(instr)
			}
			.end {
				if btidx != 0 {
					panic("Expected the VM backtrack stack to have no more elements: $btidx")
				}
	  			break
			}
			.quote {
				pos := bt.pos
				data := code[bt.pc + 1]
				bt.pos = m.quote(data, bt.pos)
				fail = pos == bt.pos
			}
		}

		if fail {
			fail = false
			bt = btstack[btidx]
			btidx --

			if keep_all_captures == false {
				idx = m.captures.len - 1
				for idx > bt.capidx && m.captures[idx].matched == false {
					idx --
				}
				m.captures.trim(idx + 1)
			}

			$if debug {
				if debug > 2 {
					eprint(" => failed: pc=$bt.pc, capidx='${m.get_capture_name_idx(bt.capidx)}'")
				}
			}
		} else {
			bt.pc += 2
		}
	}

	$if debug {
		timer.pause()
	}

	m.stats.instr_count += instr_count

	if m.captures.len == 0 {
		panic("Expected to find at least one matched or un-matched Capture")
	}

	m.matched = m.captures[0].matched
	m.pos = if m.matched { m.captures[0].end_pos } else { start_pos }
	m.btidx = btidx
	m.btstack = btstack
	m.capidx = bt.capidx

	return m.matched
}

[params]
pub struct VMContinueOptions {
	entrypoint string
}

pub fn (mut m Match) vm_continue(args VMContinueOptions) ? bool {
	if m.rplx.entrypoints.len() > 1 && args.entrypoint.len == 0 {
		names := m.rplx.entrypoints.names()
		panic("The RPL byte-code has multiple entrypoints: ${names}. Please provide the one to use.")
	}

	mut start_pc := 0
	if args.entrypoint.len > 0 {
		start_pc = m.rplx.entrypoints.find(args.entrypoint)?
	}

	m.captures.clear()
	m.btidx = 0
	m.btstack[m.btidx] = BTEntry{ pc: m.rplx.code.len }		// end of instructions => return from VM
	m.add_btentry(m.btidx)

	return m.vm(start_pc, m.pos)
}

[params]
pub struct VMMatchArgs {
	input string [required]
	entrypoint string
}

// vm_match C
// Can't use match() as "match" is a reserved word in V-lang
pub fn (mut m Match) vm_match(args VMMatchArgs) ? bool {
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
	m.input = args.input
	m.pos = 0

	return m.vm_continue(entrypoint: args.entrypoint)
}

//[inline]
[direct_array_access]
pub fn (m Match) jmp_addr(pc int) int {
	code := m.rplx.code
	p := pc + 1
	return if p < code.len { pc + int(code[p]) } else { 0 }
}

[direct_array_access]
pub fn (m Match) set_instr(instr Slot, ch byte) bool {
	cs := m.rplx.charsets[instr.aux()]
	return cs.contains(ch) == false
}

// [inline]
[direct_array_access]
pub fn (mut m Match) span(instr Slot, btpos int) int {
	mut pos := btpos
	cs := m.rplx.charsets[instr.aux()]
	for pos < m.input.len && cs.contains(m.input[pos]) {
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
	// capname := m.rplx.symbols.get(instr.aux())
	level := if m.captures.len == 0 { 0 } else { m.captures[bt.capidx].level + 1 }	// TODO can we avoid this?

	m.captures << rosie.Capture {
		matched: false,
		//name: capname,
		idx: instr.aux(),
		start_pos: bt.pos,
		level: level,
		parent: bt.capidx,
	}

	$if debug {
		m.captures[m.captures.len - 1].timer = time.sys_mono_now()
	}

	if m.stats.capture_len < m.captures.len {
		m.stats.capture_len = m.captures.len
	}

	return m.captures.len - 1
}

//[inline]
[direct_array_access]
fn (m Match) close_capture(pos int, capidx int) int {
	mut cap := &m.captures[capidx]
	cap.end_pos = pos
	cap.matched = true
	$if debug {
		cap.timer = time.sys_mono_now() - cap.timer
	}
	if !isnil(m.cap_notification) { m.cap_notification(capidx, m.fn_cap_ref) }
	return cap.parent
}

//[inline]
fn (mut m Match) add_btentry(btidx int) {
	if btidx >= (100 - 1) { panic("RPL VM stack-overflow?") }
	//$if debug {
	if m.stats.backtrack_len < btidx {
		m.stats.backtrack_len = btidx
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

[direct_array_access]
fn (m Match) until_set(instr Slot, btpos int) int {
	cs := m.rplx.charsets[instr.aux()]
	mut pos := btpos
	for pos < m.input.len && cs.contains(m.input[pos]) == false {
		pos ++
	}
	return pos
}

[direct_array_access]
fn (m Match) until_char(instr Slot, btpos int) int {
	ch := instr.ichar()
	mut pos := btpos
	for pos < m.input.len && m.input[pos] != ch {
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
	if rosie.cs_alnum.contains(cur) == true && rosie.cs_alnum.contains(back) == false {
		return pos
	}
	if rosie.cs_punct.contains(cur) == true || rosie.cs_punct.contains(back) == true {
		return pos
	}
	if rosie.cs_space.contains(back) == true && rosie.cs_space.contains(cur) == false {
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

fn (m Match) find_first_unmatched_parent(idx int) int {
	mut i := idx
	for i > 0 {
		i = m.captures[i].parent
		cap := m.captures[i]
		name := m.get_capture_name_idx(i)
		if cap.matched == false || name in m.recursives { return i }
	}
	return 0
}

fn (m Match) have_common_ancestor(capidx int, nodeidx int) bool {
	if capidx == nodeidx { return true }

	mut i := capidx
	for i > 0 {
		i = m.captures[i].parent
		if i == nodeidx { return true }
	}
	return false
}

fn (m Match) find_backref(name string, capidx int) ? &rosie.Capture {
	//eprintln(m.captures)
	for i := m.captures.len - 1; i >= 0; i-- {
		cap := &m.captures[i]
		if cap.matched && m.get_capture_name_idx(i) == name {
			//eprintln("\nFound backref by name: $i")
			idx := m.find_first_unmatched_parent(i)
			//eprintln("first unmatched parent: $idx, capidx: $capidx")
			if m.have_common_ancestor(capidx, idx) {
				//eprintln("has common ancestor: idx: $idx")
				return &m.captures[i]
			}
		}
	}

	return error("Backref not found: '$name'")
}

[direct_array_access]
fn (m Match) quote(data int, btpos int) int {
	ch1 := m.input[btpos]

	unsafe {
		ptr := &byte(&data)
		a_quote := ptr[0]
		b_quote := ptr[1]

		if ch1 == a_quote || ch1 == b_quote {
			esc := ptr[2]
			stop := ptr[3]

			mut pos := btpos + 1
			for pos < m.input.len {
				ch2 := m.input[pos]
				pos ++
				if ch2 == ch1 { return pos }
				if ch2 == esc { pos ++ }
				if ch2 == stop { break }
			}
		}
	}
	return btpos
}
