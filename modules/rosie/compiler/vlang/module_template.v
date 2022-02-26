module vlang

import rosie

struct Matcher {
pub:
	input string
pub mut:
	pos int
	capture_level int
	parent_idx int
	captures []rosie.Capture
}

pub fn new_matcher(input string) Matcher {
	return Matcher{ input: input }
}

fn (mut m Matcher) new_capture(idx int) &rosie.Capture {
	defer {
		m.capture_level ++
		m.parent_idx = m.captures.len - 1
	}

	m.captures << rosie.Capture {
		parent: m.parent_idx
		idx: idx
		level: m.capture_level
		start_pos: m.pos
	}

	return &m.captures[m.captures.len - 1]
}

fn (mut m Matcher) pop_capture(cap rosie.Capture) {
	m.capture_level -= 1
	m.parent_idx = cap.parent
}

fn (mut m Matcher) match_char(b byte) bool {
	if m.pos < m.input.len && m.input[m.pos] == b {
		m.pos ++
		return true
	}
	return false
}

fn (mut m Matcher) span_char(b byte) bool {
	for m.match_char(b) {}
	return true
}

fn (mut m Matcher) match_charset(cs rosie.Charset) bool {
	if m.pos < m.input.len && cs.contains(m.input[m.pos]) {
		m.pos ++
		return true
	}
	return false
}

fn (mut m Matcher) span_charset(cs rosie.Charset) bool {
	for m.match_charset(cs) { }
	return true
}

fn (mut m Matcher) match_literal(str string) bool {
	if (m.pos + str.len) > m.input.len {
		return false
	}

	mut i := 0
	for m.pos < m.input.len && i < str.len {
		if m.input[m.pos] != str[i] {
			return false
		}
		m.pos ++
		i ++
	}
	return i == str.len
}

//[direct_array_access]
fn (mut m Matcher) match_word_boundary() bool {
	// The boundary symbol, ~, is an ordered choice of:
	//   [:space:]+                   consume all whitespace
	//   { >word_char !<word_char }   looking at a word char, and back at non-word char
	//   >[:punct:] / <[:punct:]      looking at punctuation, or back at punctuation
	//   { <[:space:] ![:space:] }    looking back at space, but not ahead at space
	//   $                            looking at end of input
	//   ^                            looking back at start of input
	// where word_char is the ASCII-only pattern [[A-Z][a-z][0-9]]

	mut new_pos := m.pos
	for ; new_pos < m.input.len; new_pos++ {
		ch := m.input[new_pos]
		if ch == 32 { continue }
		if ch >= 9 && ch <= 13 { continue }
		break
	}

	if new_pos > m.pos {
		m.pos = new_pos
		return true
	}

	if m.pos == 0 || m.pos >= m.input.len {
		return true
	}

	back := m.input[m.pos - 1]
	cur := m.input[m.pos]
	if rosie.cs_alnum.contains(cur) == true && rosie.cs_alnum.contains(back) == false {
		return true
	}
	if rosie.cs_punct.contains(cur) == true || rosie.cs_punct.contains(back) == true {
		return true
	}
	if rosie.cs_space.contains(back) == true && rosie.cs_space.contains(cur) == false {
		return true
	}

	return false
}

//[direct_array_access]
fn (mut m Matcher) match_dot_instr() bool {
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

	b1 := m.input[m.pos] or { return false }
	if (b1 & 0x80) == 0 {
		m.pos ++
		return true
	}

	rest := m.input.len - m.pos
	if rest > 1 {
		b2 := m.input[m.pos + 1]
		b2_follow := m.is_utf8_follow_byte(b2)

		if b1 >= 0xC2 && b1 <= 0xDF && b2_follow {
			m.pos += 2
			return true
		}

		if rest > 2 {
			b3 := m.input[m.pos + 2]
			b3_follow := m.is_utf8_follow_byte(b3)

			if b1 == 0xE0 && b2 >= 0xA0 && b2 <= 0xBF && b3_follow {
				m.pos += 3
				return true
			}

			if b1 >= 0xE1 && b1 <= 0xEC && b2_follow && b3_follow {
				m.pos += 3
				return true
			}

			if b1 == 0xED && b2 >= 0x80 && b2 <= 0x9F && b3_follow {
				m.pos += 3
				return true
			}

			if b1 >= 0xEE && b1 <= 0xEF && b2_follow && b3_follow {
				m.pos += 3
				return true
			}

			if rest > 3 {
				b4 := m.input[m.pos + 3]
				b4_follow := m.is_utf8_follow_byte(b4)

				if b1 == 0xF0 && b2 >= 0x90 && b2 <= 0xBF && b3_follow && b4_follow {
					m.pos += 4
					return true
				}

				if b1 >= 0xF1 && b1 <= 0xF3 && b2_follow && b3_follow && b4_follow {
					m.pos += 4
					return true
				}

				if b1 == 0xF4 && b2_follow && b3_follow && b4_follow {
					m.pos += 4
					return true
				}
			}
		}
	}

	return false
}

[inline]
fn (m Matcher) is_utf8_follow_byte(b byte) bool {
	return b >= 0x80 && b <= 0xBF
}

fn (mut m Matcher) match_backref() bool {
	return false
}

//[direct_array_access]
fn (mut m Matcher) match_quote(esc byte, stop byte) bool {
	if (m.pos + 2) >= m.input.len { return false }
	
	start_pos := m.pos
	ch1 := m.input[m.pos]
	m.pos ++
	for ; m.pos < m.input.len; m.pos++ {
		ch2 := m.input[m.pos]
		if ch2 == ch1 {
			m.pos ++
			return true
		}
		if ch2 == esc {
			m.pos ++
		}
		if ch2 == stop {
			break
		}
	}
	m.pos = start_pos
	return false
}

fn (mut m Matcher) match_until(until byte) bool {
	for ;m.pos < m.input.len; m.pos++ {
		if m.input[m.pos] == until {
			// TODO may be "until" should be redefined to stop at the match
			m.pos ++
			break
		}
	}
	return true
}

fn (mut m Matcher) match_find() bool {
	// TODO This is a dummy only and requires implementation
	//cap1 := m.new_capture(m.pos) // "find:<search>"
	//cap2 := m.new_capture(m.pos) // "find:*"
	return false
}