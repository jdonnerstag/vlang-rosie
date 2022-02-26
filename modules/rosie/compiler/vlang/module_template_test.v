module vlang

import rosie

fn test_match_char() ? {
	mut m := new_matcher("")
	assert m.match_char(`a`) == false
	assert m.pos == 0

	m = new_matcher("a")
	assert m.match_char(`a`) == true
	assert m.pos == 1
}

fn test_span_char() ? {
	mut m := new_matcher("")
	assert m.span_char(`a`) == true
	assert m.pos == 0

	m = new_matcher("a")
	assert m.span_char(`a`) == true
	assert m.pos == 1

	m = new_matcher("aaaa")
	assert m.span_char(`a`) == true
	assert m.pos == 4

	m = new_matcher("aaab")
	assert m.span_char(`a`) == true
	assert m.pos == 3
}

fn test_match_charset() ? {
	cs := rosie.new_charset_from_rpl("aA")
	mut m := new_matcher("")
	assert m.match_charset(cs) == false
	assert m.pos == 0

	m = new_matcher("a")
	assert m.match_charset(cs) == true
	assert m.pos == 1

	m = new_matcher("A")
	assert m.match_charset(cs) == true
	assert m.pos == 1
}

fn test_span_charset() ? {
	cs := rosie.new_charset_from_rpl("aA")
	mut m := new_matcher("")
	assert m.span_charset(cs) == true
	assert m.pos == 0

	m = new_matcher("a")
	assert m.span_charset(cs) == true
	assert m.pos == 1

	m = new_matcher("aAAa")
	assert m.span_charset(cs) == true
	assert m.pos == 4

	m = new_matcher("Aaab")
	assert m.span_charset(cs) == true
	assert m.pos == 3
}

fn test_match_literal() ? {
	mut m := new_matcher("")
	assert m.match_literal("ab") == false
	assert m.pos == 0

	m = new_matcher("a")
	assert m.match_literal("ab") == false
	assert m.pos == 0

	m = new_matcher("ab")
	assert m.match_literal("ab") == true
	assert m.pos == 2

	m = new_matcher("abc")
	assert m.match_literal("ab") == true
	assert m.pos == 2

	m = new_matcher("a")
	assert m.match_literal("") == true	// empty literal => true
	assert m.pos == 0
}

fn test_match_word_boundary() ? {
	mut m := new_matcher("")
	assert m.match_word_boundary() == true
	assert m.pos == 0

	m = new_matcher("ab")
	m.pos = 1
	assert m.match_word_boundary() == false
	assert m.pos == 1

	m = new_matcher("ab")
	m.pos = 2
	assert m.match_word_boundary() == true
	assert m.pos == 2

	m = new_matcher("a b")
	m.pos = 1
	assert m.match_word_boundary() == true
	assert m.pos == 2

	m = new_matcher("a.b")
	m.pos = 1
	assert m.match_word_boundary() == true
	assert m.pos == 1	// wb only consumes spaces

	m = new_matcher("a  b")
	m.pos = 1
	assert m.match_word_boundary() == true
	assert m.pos == 3

	m = new_matcher("ab")
	m.pos = 2
	assert m.match_word_boundary() == true
	assert m.pos == 2
}

fn test_match_dot() ? {
	mut m := new_matcher("")
	assert m.match_dot_instr() == false
	assert m.pos == 0

	m = new_matcher("a")
	assert m.match_dot_instr() == true
	assert m.pos == 1

	m = new_matcher("µ")
	assert m.match_dot_instr() == true
	assert m.pos == 2

	m = new_matcher("☃")	// snowman
	assert m.match_dot_instr() == true
	assert m.pos == 3
}
/* TODO
fn (mut m Matcher) match_backref() bool {
	return false
}
*/

fn test_match_quote() ? {
	mut m := new_matcher("")
	assert m.match_quote(`\\`, `\n`) == false
	assert m.pos == 0

	m = new_matcher("a")
	assert m.match_quote(`\\`, `\n`) == false
	assert m.pos == 0

	m = new_matcher("'test'")
	assert m.match_quote(`\\`, `\n`) == true
	assert m.pos == 6

	m = new_matcher('"test"')
	assert m.match_quote(`\\`, `\n`) == true
	assert m.pos == 6

	m = new_matcher(r"'a\\b' xyz")
	assert m.match_quote(`\\`, `\n`) == true
	assert m.pos == 6

	m = new_matcher("'a\nb'")
	assert m.match_quote(`\\`, `\n`) == false
	assert m.pos == 0

	m = new_matcher("'a\nb'")
	assert m.match_quote(`\\`, 0) == true
	assert m.pos == 5
}

fn test_match_until() ? {
	mut m := new_matcher("")
	assert m.match_until(`\n`) == true
	assert m.pos == 0

	m = new_matcher("a")
	assert m.match_until(`\n`) == true
	assert m.pos == 1

	m = new_matcher("a\nb")
	assert m.match_until(`\n`) == true
	assert m.pos == 2
}
/* TODO
fn (mut m Matcher) match_find() bool {
	// TODO This is a dummy only and requires implementation
	//cap1 := m.new_capture(m.pos) // "find:<search>"
	//cap2 := m.new_capture(m.pos) // "find:*"
	return false
}
/* */
