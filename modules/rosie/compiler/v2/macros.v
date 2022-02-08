module v2

import rosie


struct MacroBE {
pub:
	pat rosie.Pattern
	elem rosie.MacroPattern
}


fn (cb MacroBE) compile(mut c Compiler) ? {
	mut x := DefaultPatternCompiler{
		pat: cb.pat,
		predicate_be: DefaultPredicateBE{ pat: cb.pat },
		compile_1_be: cb,
		compile_0_to_many_be: DefaultCompile_0_to_many{ pat: cb.pat, compile_1_be: cb }
	}

	x.compile(mut c) ?
}

fn (cb MacroBE) compile_1(mut c Compiler) ? {
	match cb.elem.name {
		"backref" { cb.compile_backref(mut c, cb.elem.pat)? }
		"word_boundary" { cb.compile_word_boundary(mut c) }
		"dot_instr" { cb.compile_dot_instr(mut c) }
		"halt" { cb.compile_halt(mut c, cb.elem.pat) ? }
		"quote" { cb.compile_quote(mut c, cb.elem.pat) ? }
		"until" { cb.compile_until(mut c, cb.elem.pat) ? }
		else { return error("The selected compiler backend has no support for macro/function: '$cb.elem.name' => ${cb.pat.repr()}") }
	}
}

fn (cb MacroBE) compile_backref(mut c Compiler, pat rosie.Pattern) ? {
	if pat.elem is rosie.NamePattern {
		name := c.current.get(pat.elem.name)?.full_name()
		c.add_backref(name)?
		return
	}

	return error("Backref must be a NamePattern")
}

[inline]
fn (cb MacroBE) compile_word_boundary(mut c Compiler) {
	c.add_word_boundary()
}

[inline]
fn (cb MacroBE) compile_dot_instr(mut c Compiler) {
	c.add_dot_instr()
}

fn (cb MacroBE) is_single_alias(pat rosie.Pattern) bool {
	if pat.elem is rosie.NamePattern {
		return true
	}

	if g := pat.is_group() {
		if pat.is_standard() && g.ar.len == 1 {
			if g.ar[0].is_standard() {
				return cb.is_single_alias(g.ar[0])
			}
		}
	}
	return false
}

fn (cb MacroBE) compile_halt(mut c Compiler, pat rosie.Pattern) ? {
	// Irrespective whether the child-pattern succeeds or fails, we want to halt
	// program execution. Program continuation should be possible, exactly as
	// if execution was not stopped.

	if cb.is_single_alias(pat) {
		c.add_halt_capture()			// Remember the next capture that will happen in the child-pattern
		p1 := c.add_choice(0)			// We need to intercept success and failures
		c.compile_elem(pat, pat)?		// Process the child-pattern
		p2 := c.add_commit(0)			// Pop choice stack and continue with the next statement
		c.update_addr(p2, c.rplx.code.len)
		c.add_halt()					// Halt execution
		p3 := c.add_jmp(0)				// Upon continue, continue with 'success' part
		c.update_addr(p1, c.rplx.code.len)  // Upon child pattern failure, continue here
		c.add_halt()					// Stop execution
		c.add_fail()					// Upon continue, continue as if child pattern failed
		c.update_addr(p3, c.rplx.code.len)
	} else {
		// Add an additional "_halt_" capture
		c.add_halt_capture()			// Remember the next capture that will happen in the child-pattern
		p1 := c.add_choice(0)			// We need to intercept success and failures
		c.add_open_capture("_halt_")
		c.compile_elem(pat, pat)?		// Process the child-pattern
		c.add_close_capture()
		p2 := c.add_commit(0)			// Pop choice stack and continue with the next statement
		c.update_addr(p2, c.rplx.code.len)
		c.add_halt()					// Halt execution
		p3 := c.add_jmp(0)				// Upon continue, continue with 'success' part
		c.update_addr(p1, c.rplx.code.len)  // Upon child pattern failure, continue here
		c.add_halt()					// Stop execution
		c.add_fail()					// Upon continue, continue as if child pattern failed
		c.update_addr(p3, c.rplx.code.len)
	}
}

fn (cb MacroBE) compile_quote(mut c Compiler, pat rosie.Pattern) ? {
	quote := cb.get_quote_arg(pat, 0, 2)?
	esc := cb.get_quote_arg(pat, 1, 1)?
	stop := cb.get_quote_arg(pat, 2, 1)?

	cs1 := quote[0]
	cs2 := quote[1] or { cs1 }
	c.add_quote(cs1, cs2, esc[0], stop[0])
}

fn (cb MacroBE) get_quote_arg(pat rosie.Pattern, i int, len int) ? string {
	if pat.elem is rosie.GroupPattern {
		if pat.elem.ar.len > i {
			p1 := pat.elem.ar[i]
			if p1.elem is rosie.CharsetPattern {
				str := p1.elem.cs.to_charlist()
				if str.len > 0 && str.len <= len {
					return str
				}
			} else if p1.elem is rosie.LiteralPattern {
				str := p1.elem.text
				if str.len > 0 && str.len <= len {
					return str
				}
			}
		} else {
			return ""
		}
	}
	return error("Macro 'quote' requires a GroupPattern with 1-3 entries, e.g. quote:{[\"\'] [\\] [\\n]}")
}

fn (cb MacroBE) compile_until(mut c Compiler, pat rosie.Pattern) ? {
	if pat.elem is rosie.CharsetPattern {
		cs := pat.elem.cs
		count, ch := cs.count()
		if count == 1 {
			c.add_until_char(ch, false)
			return
		} else {
			c.add_until_set(pat.elem.cs, false)
			return
		}
	} else if pat.elem is rosie.LiteralPattern {
		str := pat.elem.text
		if str.len == 1 {
			c.add_until_char(str[0], false)
			return
		}
	}
	return error("Macro 'until' requires exactly 1 parameter, e.g. until:[\\n]")
}
