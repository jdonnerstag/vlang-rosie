module runtime_v2


type CaptureFn = fn (capidx int)

// Match Manage the matching process
struct Match {
	rplx Rplx					// The rplx data (compiled RPL)
	debug int					// 0 - no debugging; the larger, the more debug message
	cap_notification CaptureFn	// Notify user about a new (positiv) capture

pub mut:
	package string = "main"		// Default package name, if not provided
  	input string		// input data
	pos int

	captures []Capture	// The tree of captures
	stats Stats			// Collect some statistics

  	matched bool
	recursives []string = []		// Bindings which are recursive
}

// new_match Create a new 'Match' object
pub fn new_match(rplx Rplx, debug int) Match {
  	return Match {
		rplx: rplx,
		captures: []Capture{ cap: 10 },
		stats: new_stats(),
		matched: true,
		debug: debug,
	}
}

// instruction Given the program counter determine the Instruction
[inline]
fn (m Match) instruction(pc int) Slot { return m.rplx.slot(pc) }

// eof True, of the all of the input has been consumed already.
[inline]
fn (m Match) eof(pos int) bool { return pos >= m.input.len }

// leftover A pattern may not match the complete input. Return what is left.
[inline]
fn (m Match) leftover() string { return m.input[m.pos ..] }

// cmp_char Given a byte at a specific position within the input data,
// compare it with the byte provided. Return false if already reached
// end of the input data.
[inline]
fn (m Match) cmp_char(pos int, ch byte) bool {
	return !m.eof(pos) && m.input[pos] == ch
}

[inline]
fn (m Match) bit_7(pos int) bool {
	return m.eof(pos) || (m.input[pos] & 0x80) != 0
}

// testchar Compare the byte at a specific position within the input data
// against the charset provided with the byte code instruction
[inline]
fn (m Match) testchar(pos int, pc int) bool {
	return !m.eof(pos) && testchar(m.input[pos], m.rplx.code, pc)
}

// has_match Determine whether any of the captured values has the name provided.
[inline]
pub fn (m Match) has_match(pname string) bool {
	return if _ := m.get_match_by(pname) { true } else { false }
}

// get_match_by Find a Capture by name
// Examples:
// m.get_match_by("*", "rpl_1_1.exp", "rpl_1_1.grammar-3.arg")? == "(x y)"
// m.get_match_by("rpl_1_1.exp", "rpl_1_1.grammar-3.arg")? == "(x y)"
// m.get_match_by("exp", "rpl_1_1.grammar-3.arg")? == "(x y)"
// m.get_match_by("exp", "grammar-3.arg")? == "(x y)"
// m.get_match_by("exp", "arg")? == "(x y)"
// m.get_match_by("*", "exp", "arg")? == "(x y)"
// m.get_match_by("exp.arg")? == "(x y)"
pub fn (m Match) get_match_by(path ...string) ?string {
	if path.len == 0 {
		return error("ERROR: get_match_by(): at least 1 path element must be provided")
	}

	mut stack := []string{}
	mut idx := -1
	mut level := 0
	for p in path {
		stack << p
		p2 := if p.contains(".") { p } else { m.package + "." + p }
		idx, level = m.get_all_match_by_(idx + 1, level, p, p2, true) or {
			if path.len == 1 && p.contains(".") {
				pelems := p.split(".")
				return m.get_match_by(...pelems)
			}
			return error("Capture with path $stack not found")
		}
	}

	cap := m.captures[idx]
	return m.input[cap.start_pos .. cap.end_pos]
}

fn (m Match) get_all_match_by_(start_idx int, start_level int, child1 string, child2 string, endswith bool) ? (int, int) {
	for i := start_idx; i < m.captures.len; i++ {
		cap := m.captures[i]
		if cap.level < start_level {
			break
		}

		if cap.matched {
			if cap.name in [child1, child2] {
				return i, cap.level
			} else if endswith && cap.name.ends_with("." + child1) {
				return i, cap.level
			}
		}
	}

	return none
}

pub fn (m Match) get_all_match_by(path ...string) ? []string {
	mut stack := []string{}
	mut idx := 0
	mut level := 0
	for p in path {
		stack << p
		p2 := if p.contains(".") { p } else { m.package + "." + p }
		idx, level = m.get_all_match_by_(idx, level, p, p2, false) or {
			return error("Capture with path $stack not found")
		}
		idx += 1
	}

	if idx > 0 { idx -= 1 }
	level -= 1
	mut p := stack.last()
	mut ar := []string{}
	for true {
		cap := m.captures[idx]
		ar << m.input[cap.start_pos .. cap.end_pos]

		p2 := if p.contains(".") { p } else { m.package + "." + p }
		idx, level = m.get_all_match_by_(idx + 1, level, p, p2, false) or {
			break
		}
	}
	return ar
}

// get_match Return the main, most outer, Capture
pub fn (m Match) get_match() ?string {
	if m.captures.len > 0 {
		cap := m.captures[0]
		if cap.matched {
			return m.input[cap.start_pos .. cap.end_pos]
		}
	}
	return error("No match")
}

// get_match_names Get the list of pattern (Capture) names found.
pub fn (m Match) get_match_names() []string {
	mut rtn := []string{}
	for cap in m.captures {
		if cap.matched {
			rtn << cap.name
		}
	}
	return rtn
}

[inline]
fn (mut m Match) add_capture(cap Capture) int {
	m.captures << cap
	if m.stats.capture_len < m.captures.len { m.stats.capture_len = m.captures.len }
	return m.captures.len - 1
}

[inline]
fn (mut m Match) close_capture(pos int, capidx int) int {
	mut cap := &m.captures[capidx]
	cap.end_pos = pos
	cap.matched = true
	// if m.debug > 2 { eprint("\nCapture: ($cap.level) ${cap.name}='${m.input[cap.start_pos .. cap.end_pos]}'") }
	if !isnil(m.cap_notification) { m.cap_notification(capidx) }
	return cap.parent
}

[inline]
fn (mut m Match) add_btentry(mut btstack []BTEntry, entry BTEntry) {
	btstack << entry
	if btstack.len > 10000 { panic("RPL VM stack-overflow?") }
	if m.stats.backtrack_len < btstack.len { m.stats.backtrack_len = btstack.len }
}

fn (mut m Match) find_first_unmatched_parent(idx int) int {
	mut i := idx
	for i > 0 {
		i = m.captures[i].parent
		cap := m.captures[i]
		if cap.matched == false || cap.name in m.recursives { return i }
	}
	return 0
}

fn (mut m Match) have_common_ancestor(capidx int, nodeidx int) bool {
	if capidx == nodeidx { return true }

	mut i := capidx
	for i > 0 {
		i = m.captures[i].parent
		if i == nodeidx { return true }
	}
	return false
}

fn (mut m Match) find_backref(name string, capidx int) ? &Capture {
	//eprintln(m.captures)
	for i := m.captures.len - 1; i >= 0; i-- {
		cap := &m.captures[i]
		if cap.matched && cap.name == name {
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

// replace Replace the main pattern match
fn (mut m Match) replace(repl string) string {
	if m.matched == false || m.captures.len == 0 {
		panic("Match failed. Nothing to replace")
	}

	cap := m.captures[0]
	return m.input[0 .. cap.start_pos] + repl + m.input[cap.end_pos .. ]
}

// replace Replace the pattern match identified by name
fn (mut m Match) replace_by(name string, repl string) ?string {
	if m.matched == false || m.captures.len == 0 {
		return error("Match failed. Nothing to replace")
	}

	for cap in m.captures {
		if cap.name == name {
			if cap.matched {
				return m.input[0 .. cap.start_pos] + repl + m.input[cap.end_pos .. ]
			}
			return error("Found pattern '$name' but it didn't match")
		}
	}
	return error("Did not find pattern with name '$name'")
}

fn (mut m Match) is_word_boundary(pos int) (bool, int) {
	// The boundary symbol, ~, is an ordered choice of:
	//   [:space:]+                   consume all whitespace
	//   { >word_char !<word_char }   looking at a word char, and back at non-word char
	//   >[:punct:] / <[:punct:]      looking at punctuation, or back at punctuation
	//   { <[:space:] ![:space:] }    looking back at space, but not ahead at space
	//   $                            looking at end of input
	//   ^                            looking back at start of input
	// where word_char is the ASCII-only pattern [[A-Z][a-z][0-9]]

	// TODO could this be optimized?
	mut new_pos := pos
	for new_pos < m.input.len && m.input[new_pos] in [9, 10, 11, 12, 13, 32] {
		new_pos += 1
	}

	if new_pos > pos {
		return false, new_pos
	}

	if pos == m.input.len || pos == 0 {
		return false, pos
	}

	if pos > 0 {
		back := m.input[pos - 1]
		cur := m.input[pos]
		if cs_alnum.testchar(cur) == true && cs_alnum.testchar(back) == false {
			return false, pos
		}
		if cs_punct.testchar(cur) == true || cs_punct.testchar(back) == true {
			return false, pos
		}
		if cs_space.testchar(back) == true && cs_space.testchar(cur) == false {
			return false, pos
		}
	}

	return true, pos
}

fn (mut m Match) is_dot(pos int) (bool, int) {
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

	rest := m.input.len - pos
	if rest == 0 { return true, pos }

	b1 := m.input[pos]
	if b1 < 128 { return false, pos + 1 }

	if rest > 1 {
		b2 := m.input[pos + 1]
		b2_follow := m.is_utf8_follow_byte(b2)

		if b1 >= 0xC2 && b1 <= 0xDF && b2_follow {
			return false, pos + 2
		}

		if rest > 2 {
			b3 := m.input[pos + 2]
			b3_follow := m.is_utf8_follow_byte(b3)

			if b1 == 0xE0 && b2 >= 0xA0 && b2 <= 0xBF && b3_follow {
				return false, pos + 3
			}

			if b1 >= 0xE1 && b1 <= 0xEC && b2_follow && b3_follow {
				return false, pos + 3
			}

			if b1 == 0xED && b2 >= 0x80 && b2 <= 0x9F && b3_follow {
				return false, pos + 3
			}

			if b1 >= 0xEE && b1 <= 0xEF && b2_follow && b3_follow {
				return false, pos + 3
			}

			if rest > 3 {
				b4 := m.input[pos + 3]
				b4_follow := m.is_utf8_follow_byte(b4)

				if b1 == 0xF0 && b2 >= 0x90 && b2 <= 0xBF && b3_follow && b4_follow {
					return false, pos + 4
				}

				if b1 >= 0xF1 && b1 <= 0xF3 && b2_follow && b3_follow && b4_follow {
					return false, pos + 4
				}

				if b1 == 0xF4 && b2_follow && b3_follow && b4_follow {
					return false, pos + 4
				}
			}
		}
	}

	return true, pos
}

[inline]
fn (mut m Match) is_utf8_follow_byte(b byte) bool {
	return b >= 0x80 && b <= 0xBF
}
