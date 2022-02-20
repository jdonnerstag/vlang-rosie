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
	for m.match_char(b) {
		m.pos ++
	}
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
	for m.match_charset(cs) {
		m.pos ++
	}
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
