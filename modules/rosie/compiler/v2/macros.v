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
		else { return error("The selected compiler backend has no support for macro/function: '$cb.elem.name' => ${cb.pat.repr()}") }
	}
}

fn (cb MacroBE) compile_backref(mut c Compiler, pat rosie.Pattern) ? {
	if pat.elem is rosie.NamePattern {
		name := c.binding(pat.elem.name)?.full_name()
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

fn (cb MacroBE) compile_halt(mut c Compiler, pat rosie.Pattern) ? {
	//c.compile_elem(pat, pat)?
	//c.add_halt()
	c.add_open_capture("_halt_")
	c.add_halt_capture()
	p1 := c.add_choice(0)
	c.compile_elem(pat, pat)?
	c.add_close_capture()
	c.update_addr(p1, c.rplx.code.len)
	c.add_halt()
}
