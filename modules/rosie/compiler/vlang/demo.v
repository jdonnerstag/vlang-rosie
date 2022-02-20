module vlang

import rosie

// I've not yet started with the Compiler, but was thinking about
// how the generated code might look like.

// The compiler puts all generated code into a Vlang module (user provided name)

// See "module_template.v" for runtime components

// For every charset we create a const
const cs_1 = rosie.Charset{}

// A function per binding (capture)
fn (mut m Matcher) cap_abc() bool {
	start_pos := m.pos
	mut match_ := false
	defer { if match_ == false { m.pos = start_pos } }

	mut cap := m.new_capture(start_pos)
	defer { m.pop_capture(cap) }

	// pat = "a"
	match_ = m.match_char(`a`)
	if match_ == false {	// If predicate is `!`, then == "true"
		return false
	}

	// pat = "a"
	match_ = m.match_char(`a`)
	if match_ == false { return false }

	// pat = "a"*
	for m.pos < m.input.len {
		if m.match_charset(cs_1) == false { break }
	}

	// pat = "a"?
	m.match_charset(cs_1)

	// pat = "a"+
	m.match_charset(cs_1)
	for m.pos < m.input.len {
		if m.match_charset(cs_1) == false { break }
	}

	match_ = m.anon_or_1()
	if match_ == false { return false }

	match_ = m.anon_group_1()
	if match_ == false { return false }

	cap.end_pos = m.pos
	return true
}

// Auto generated function for each "or" group
fn (mut m Matcher) anon_or_1() bool {
	start_pos := m.pos
	mut match_ := false
	defer { if match_ == false { m.pos = start_pos } }

	match_ = m.match_char(`a`)
	if match_ == true {	return true }

	match_ = m.match_charset(cs_1)
	if match_ == true {	return true }

	return false
}

// Auto generated function for each group
// Not sure we need this. Why not simply a block?
fn (mut m Matcher) anon_group_1() bool {
	start_pos := m.pos
	mut match_ := false
	defer { if match_ == false { m.pos = start_pos } }

	match_ = m.match_char(`a`)
	if match_ == false { return false }

	match_ = m.match_charset(cs_1)
	if match_ == false { return false }

	return true
}

// Repetitions
// We can't pass a function which has a receiver.
fn (mut m Matcher) xx(min int, max int) bool {
	if min > 0 {
		for i := 0; i < min; i++ {
			if m.anon_group_1() == false {
				return false
			}
		}
	}

	if max < 0 {
		for m.pos < m.input.len {
			if m.anon_group_1() == false {
				break
			}
		}
	} else if max > min {
		for i := min; i < max; i++ {
			if m.anon_group_1() == false {
				return false
			}
		}
	}
	return true
}

// Alternative repetition which needs the "block" only ones
// For specific pattern, e.g. char/charset optimized version should be possible
fn (mut m Matcher) xy(start_pos int, min int, max int) bool {
	mut count := 0
	mut pos := start_pos
	mut match_ := false
	for pos < m.input.len {
		match_ = m.match_char(`x`)
		if match_ == false {
			break
		}
		count ++
		if max >= 0 && count >= min && count >= max {
			return true
		}
	}
	if count >= min {
		return true
	}
	return false
}

// How to do predicates
fn (mut m Matcher) xxxx(min int, max int) bool {
/*
	{
		// >(..)
		pos := m.pos
		//..
		m.pos = pos
	}
	{
		// <(..)
		pos := m.pos
		m.pos -= pat.input_len()
		//..
		m.pos = pos
	}
*/
	return false
}
