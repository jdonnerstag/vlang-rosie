module compiler_backend_vm

import rosie.parser


struct MacroBE {}

fn (mut cb MacroBE) compile(mut c Compiler, pat parser.Pattern, alias_pat parser.Pattern) ? {
	macro := alias_pat.elem as parser.MacroPattern

	pred_p1 := c.predicate_pre(pat, 0)?	// look-behind is not supported with macros

	cb.compile_inner(mut c, pat, macro)?

	c.predicate_post(pat, pred_p1)
}

fn (mut cb MacroBE) compile_inner(mut c Compiler, pat parser.Pattern, macro parser.MacroPattern) ? {
	for _ in 0 .. pat.min {
		cb.compile_1(mut c, macro)?
	}

	if pat.max != -1 {
		if pat.max > pat.min {
			cb.compile_0_to_n(mut c, macro, pat.max - pat.min)?
		}
	} else {
		cb.compile_0_to_many(mut c, macro)?
	}
}

fn (mut cb MacroBE) compile_1(mut c Compiler, macro parser.MacroPattern) ? {
	match macro.name {
		//"find" { cb.compile_find(mut c, macro.pat)? }		// moved to parser
		// "keepto" { cb.compile_keepto(mut c, macro.pat)? }	// moved to parser
		//"ci" { cb.compile_case_insensitive(mut c, macro.pat)? }	// moved to parser
		"backref" { cb.compile_backref(mut c, macro.pat)? }
		"word_boundary" { c.add_word_boundary() }
		"dot_instr" { c.add_dot_instr() }
		else { return error("The selected compiler backend has no support for macro/function: '$macro.name'") }
	}
}

fn (mut cb MacroBE) compile_0_to_many(mut c Compiler, macro parser.MacroPattern) ? {
	p1 := c.add_choice(0)
	p2 := c.code.len
	cb.compile_1(mut c, macro)?
	c.add_partial_commit(p2)
	c.update_addr(p1, c.code.len)
}

fn (mut cb MacroBE) compile_0_to_n(mut c Compiler, macro parser.MacroPattern, max int) ? {
	mut ar := []int{ cap: max }
	for _ in 0 .. max {
		ar << c.add_choice(0)
		cb.compile_1(mut c, macro)?
		p2 := c.add_commit(0)
		c.update_addr(p2, c.code.len)
	}

	for pc in ar { c.update_addr(pc, c.code.len) }
}

fn (mut cb MacroBE) compile_backref(mut c Compiler, pat parser.Pattern) ? {
	if pat.elem is parser.NamePattern {
		name := c.binding(pat.elem.name)?.full_name()
		c.add_backref(name)?
		return
	}

	return error("Backref must be a NamePattern")
}
