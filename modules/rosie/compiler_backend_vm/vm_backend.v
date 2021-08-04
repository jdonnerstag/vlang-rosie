module compiler_backend_vm

import rosie.runtime as rt
import rosie.parser

struct Compiler {
pub mut:
	parser parser.Parser		// Actually we should only need all the bindings
	symbols rt.Ktable			// capture table
  	code []rt.Slot				// byte code vector
}

pub fn new_compiler(p parser.Parser) Compiler {
	return Compiler{ parser: p, symbols: rt.new_ktable() }
}

// compile Compile the necessary instructions for a specific
// (public) binding from the rpl file. Use "*" for anonymous
// pattern.
pub fn (mut c Compiler) compile(name string) ? {
	b := c.parser.binding_(name)?

	c.symbols.add(name)
	c.code.add_open_capture(c.symbols.len())
	c.compile_elem(b.pattern)?
	c.code.add_close_capture()
	c.code.add_end()
}

pub fn (mut c Compiler) compile_elem(pat parser.Pattern) ? {
	mut p1 := 0
	if pat.predicate == .negative_look_ahead {
		p1 = c.code.add_choice(0)
	}

	match pat.elem {
		parser.LiteralPattern { c.compile_literal(pat) }
		parser.GroupPattern { c.compile_group(pat.elem)? }	// TODO leverage "multipliers" somewhere
		parser.CharsetPattern { c.compile_charset(pat) }
		parser.NamePattern { c.compile_alias(pat)? }
		// parser.AnyPattern { c.compile_dot(pat) }
		else {
			return error("Compiler does not yet support AST ${pat.elem.type_name()}")
		}
	}

	if pat.predicate == .negative_look_ahead {
		c.code.add_fail_twice()
		c.code.update_addr(p1, c.code.len - 2)
	}
}

fn (mut c Compiler) update_addr_ar(mut ar []int, pos int) {
	for p2 in ar {
		c.code.update_addr(p2, c.code.len - 2)
	}
	ar.clear()
}

pub fn (mut c Compiler) compile_group(group parser.GroupPattern) ? {
	mut last_operator := parser.OperatorType.sequence
	mut ar := []int{}

	for e in group.ar {
		if e.operator == .sequence {
			c.compile_elem(e)?

			if last_operator != .sequence {
				c.update_addr_ar(mut ar, c.code.len - 2)
			}
		} else {
			p1 := c.code.add_choice(0)
			c.compile_elem(e)?
			p2 := c.code.add_pop_choice(0)	// pop the entry added by choice
			ar << p2
			c.code.update_addr(p1, c.code.len - 2)	// TODO I think -2 should not be here
		}
		last_operator = e.operator
	}

	//c.code.add_commit(0)	// pop the entry added by choice
	c.update_addr_ar(mut ar, c.code.len - 2)
}

pub fn (mut c Compiler) compile_literal(pat parser.Pattern) {
	if pat.elem is parser.LiteralPattern {
		text := pat.elem.text
		if text.len == 0 {
			// Don't do anything
		} else if text.len == 1 {
			ch := text[0]
			if pat.is_1() { c.compile_char_1(ch) }
			else if pat.is_0_or_1() { c.compile_char_0_or_1(ch) }
			else if pat.is_0_or_many() { c.compile_char_0_or_many(ch) }
			else if pat.is_1_or_many() { c.compile_char_1_or_many(ch) }
			else  { c.compile_char_multiple(ch, pat.min, pat.max) }
		} else {
			if pat.is_1() { c.compile_literal_1(text) }
			else if pat.is_0_or_1() { c.compile_literal_0_or_1(text) }
			else if pat.is_0_or_many() { c.compile_literal_0_or_many(text) }
			else if pat.is_1_or_many() { c.compile_literal_1_or_many(text) }
			else { c.compile_literal_multiple(text, pat.min, pat.max) }
		}
	}
}

// ----------------------------------------------------------

pub fn (mut c Compiler) compile_char_1(ch byte) {
	c.code.add_char(ch)
}

pub fn (mut c Compiler) compile_char_0_or_many(ch byte) {
	c.code.add_span(rt.new_charset_with_byte(ch))
}

pub fn (mut c Compiler) compile_char_1_or_many(ch byte) {
	c.code.add_char(ch)
	c.code.add_span(rt.new_charset_with_byte(ch))
}

pub fn (mut c Compiler) compile_char_0_or_1(ch byte) {
	c.code.add_span(rt.new_charset_with_byte(ch))		// TODO The same byte-code for 0..n and 0..1 ?!?!?
}

pub fn (mut c Compiler) compile_char_multiple(ch byte, min int, max int) {
	for _ in 0 .. min {
		c.compile_char_1(ch)
	}

	mut ar := []int{}
	for _ in min .. max {
		ar << c.code.add_test_char(ch, 0)
		c.code.add_any()
	}

	p1 := c.code.len
	for i in ar {
		c.code.update_addr(i, p1 - 2)	// TODO +2, -2, need to fix this. There is some misunderstanding.
	}
}

// ----------------------------------------------------------

pub fn (mut c Compiler) compile_literal_1(text string) {
	for ch in text {
		c.code.add_char(ch)
	}
}

pub fn (mut c Compiler) compile_literal_0_or_many(text string) {
	p1 := c.code.add_test_char(text[0], 0)
	p2 := c.code.add_choice(0)
	p3 := c.code.len
	c.compile_literal_1(text)
	p4 := c.code.add_partial_commit(p3)
	c.code.update_addr(p1, p4)
	c.code.update_addr(p2, p4)
}

pub fn (mut c Compiler) compile_literal_1_or_many(text string) {
	c.compile_literal_1(text)
	p1 := c.code.add_test_char(text[0], 0)
	p2 := c.code.add_choice(0)
	p3 := c.code.len
	c.compile_literal_1(text)
	p4 := c.code.add_partial_commit(p3)
	c.code.update_addr(p1, p4)
	c.code.update_addr(p2, p4)
}

pub fn (mut c Compiler) compile_literal_0_or_1(text string) {
	c.code.add_span(rt.new_charset_with_byte(text[0]))
	c.compile_literal_1(text)
}

pub fn (mut c Compiler) compile_literal_multiple(text string, min int, max int) {
	for _ in 0 .. min {
		c.compile_literal_1(text)
	}

	ch := text[0]
	p1 := c.code.add_test_char(ch, 0)
	p2 := c.code.add_choice(0)
	c.code.add_any()
	c.compile_literal_1(text[1 ..])
	c.code.add_partial_commit(c.code.len + 2)
	c.compile_literal_1(text)
	c.code.add_commit(c.code.len)

	p3 := c.code.len
	c.code.update_addr(p1, p3 - 2)
	c.code.update_addr(p2, p3 - 2)
}

// ----------------------------------------------------------

pub fn (mut c Compiler) compile_charset(pat parser.Pattern) {
	if pat.elem is parser.CharsetPattern {
		cs := pat.elem.cs
		if pat.is_1() { c.compile_charset_1(cs) }
		else if pat.is_0_or_1() { c.compile_charset_0_or_1(cs) }
		else if pat.is_0_or_many() { c.compile_charset_0_or_many(cs) }
		else if pat.is_1_or_many() { c.compile_charset_1_or_many(cs) }
		else  { c.compile_charset_multiple(cs, pat.min, pat.max) }
	}
}

pub fn (mut c Compiler) compile_charset_1(cs rt.Charset) {
	c.code.add_set(cs)
}

pub fn (mut c Compiler) compile_charset_0_or_many(cs rt.Charset) {
	c.code.add_span(cs)
}

pub fn (mut c Compiler) compile_charset_1_or_many(cs rt.Charset) {
	c.code.add_set(cs)
	c.code.add_span(cs)
}

pub fn (mut c Compiler) compile_charset_0_or_1(cs rt.Charset) {
	c.code.add_span(cs)			// TODO The same byte code for 0..n and 0..1 ???
}

pub fn (mut c Compiler) compile_charset_multiple(cs rt.Charset, min int, max int) {
	for _ in 0 .. min {
		c.compile_charset_1(cs)
	}

	mut ar := []int{}
	for _ in min .. max {
		ar << c.code.add_test_set(cs, 0)
		c.code.add_any()
	}

	p1 := c.code.len
	for i in ar {
		c.code.update_addr(i, p1 - 2)	// TODO +2, -2, need to fix this. There is some misunderstanding.
	}
}

// ----------------------------------------------------------

pub fn (mut c Compiler) compile_alias(pat parser.Pattern) ? {
	if pat.elem is parser.NamePattern {
		name := pat.elem.text
		b := c.parser.binding_(name)?
		if b.alias == false {
			idx := c.symbols.find(name) or {
				c.symbols.add(name)
				c.symbols.len()
			}
			c.code.add_open_capture(idx)
		}

		alias_pat := b.pattern
		c.compile_elem(alias_pat)?

		if b.alias == false {
			c.code.add_close_capture()
		}
	}
}

pub fn (mut c Compiler) compile_dot(pat parser.Pattern) {
	if pat.elem is parser.AnyPattern {
		panic("Compiler ERROR: dot pattern not yet implemented")
	}
}
