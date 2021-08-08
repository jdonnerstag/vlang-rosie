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
	c.compile_elem(b.pattern, b.pattern)?
	c.code.add_close_capture()
	c.code.add_end()
}

fn (mut c Compiler) compile_elem(pat parser.Pattern, alias_pat parser.Pattern) ? {
	if pat.elem is parser.LiteralPattern {
		if pat.elem.text.len == 1 {
			mut be := CharBE{}
			be.compile(mut c, pat, pat.elem.text[0])
		} else {
			mut be := StringBE{}
			be.compile(mut c, pat, pat.elem.text)
		}
		return
	} else if pat.elem is parser.CharsetPattern {
		mut be := CharsetBE{}
		be.compile(mut c, pat, pat.elem.cs)
		return
	}

	mut pred_p1 := 0
	if pat.predicate == .negative_look_ahead {
		pred_p1 = c.code.add_choice(0)
	}

	defer {
		if pat.predicate == .negative_look_ahead {
			c.code.add_fail_twice()
			c.code.update_addr(pred_p1, c.code.len - 2)
		}
	}

	// 1) If there is a fixed number of tests required, then test them first
	// 2) If the upper limit is fixed, then add n tests
	// 3) If no upper limit, then add appropriate choice instruction
	for _ in 0 .. pat.min {
		c.compile_elem_inner(alias_pat)?
	}

	if pat.max != -1 {
		if pat.max > pat.min {
			for _ in pat.min .. pat.max {
				p1 := c.code.add_choice(0)
				c.compile_elem_inner(alias_pat)?
				p2 := c.code.add_pop_choice(0)
				c.code.update_addr(p1, c.code.len - 2)	// TODO +2, -2, need to fix this. There is some misunderstanding.
				c.code.update_addr(p2, c.code.len - 2)	// TODO +2, -2, need to fix this. There is some misunderstanding.
			}
		}
	} else {
		p1 := c.code.add_choice(0)
		p2 := c.code.len
		c.compile_elem_inner(alias_pat)?
		c.code.add_jmp(p2 - 2)
		c.code.add_pop_choice(0)
		c.code.update_addr(p1, c.code.len - 2)	// TODO +2, -2, need to fix this. There is some misunderstanding.
		c.code.update_addr(p2, c.code.len - 2)	// TODO +2, -2, need to fix this. There is some misunderstanding.
	}
}

fn (mut c Compiler) compile_elem_inner(pat parser.Pattern) ? {
	match pat.elem {
		parser.LiteralPattern { panic("Should never happen") }
		parser.GroupPattern { c.compile_group(pat.elem)? }	// TODO leverage "multipliers" somewhere
		parser.CharsetPattern { panic("Should never happen") }
		parser.NamePattern { c.compile_alias(pat)? }
		parser.AnyPattern { c.compile_dot(pat)? }
	}
}

fn (mut c Compiler) update_addr_ar(mut ar []int, pos int) {
	for p2 in ar {
		c.code.update_addr(p2, c.code.len - 2)
	}
	ar.clear()
}

fn (mut c Compiler) compile_group(group parser.GroupPattern) ? {
	mut ar := []int{}

	for e in group.ar {
		if e.operator == .sequence {
			c.compile_elem(e, e)?

			if ar.len > 0 {
				c.code.add_fail()
				c.update_addr_ar(mut ar, c.code.len - 2)
			}
		} else {
			p1 := c.code.add_choice(0)
			c.compile_elem(e, e)?
			p2 := c.code.add_pop_choice(0)	// pop the entry added by choice
			ar << p2
			c.code.update_addr(p1, c.code.len - 2)	// TODO I think -2 should not be here
		}
	}

	if ar.len > 0 {
		c.code.add_fail()
		c.update_addr_ar(mut ar, c.code.len - 2)
	}
}

// ----------------------------------------------------------

fn (mut c Compiler) compile_alias(pat parser.Pattern) ? {
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

		c.compile_elem(pat, b.pattern)?		// TODO Doesn't it have to be .._inner() ???

		if b.alias == false {
			c.code.add_close_capture()
		}
	}
}

fn (mut c Compiler) compile_dot(pat parser.Pattern) ? {
	if pat.elem is parser.AnyPattern {
		alias_pat := c.parser.package.get(".")?.pattern
		c.compile_elem_inner(alias_pat)?
	}
}
