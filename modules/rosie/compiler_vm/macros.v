module compiler_vm

import rosie.parser


struct MacroBE {
pub:
	pat parser.Pattern
	elem parser.MacroPattern
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
		//"find" { cb.compile_find(mut c, macro.pat)? }		// moved to parser
		// "keepto" { cb.compile_keepto(mut c, macro.pat)? }	// moved to parser
		// "findall" { cb.compile_find(mut c, macro.pat)? }		// moved to parser
		//"ci" { cb.compile_case_insensitive(mut c, macro.pat)? }	// moved to parser
		"backref" { cb.compile_backref(mut c, cb.elem.pat)? }
		"word_boundary" { cb.compile_word_boundary(mut c) }
		"dot_instr" { cb.compile_dot_instr(mut c) }
		else { return error("The selected compiler backend has no support for macro/function: '$cb.elem.name'") }
	}
}

fn (cb MacroBE) compile_backref(mut c Compiler, pat parser.Pattern) ? {
	if pat.elem is parser.NamePattern {
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
