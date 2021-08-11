module compiler_backend_vm

import rosie.parser


struct MacroBE {}

fn (mut cb MacroBE) compile(mut c Compiler, pat parser.Pattern, alias_pat parser.Pattern) ? {
	macro := alias_pat.elem as parser.MacroPattern

	pred_p1 := c.predicate_pre(pat, 0)	// look-behind is not supported with macros

	cb.compile_inner(mut c, pat, macro)?

	c.predicate_post(pat, pred_p1)
}

fn (mut cb MacroBE) compile_inner(mut c Compiler, pat parser.Pattern, macro parser.MacroPattern) ? {
	for _ in 0 .. pat.min {
		cb.compile_1(mut c, macro)?
	}

	if pat.max != -1 {
		if pat.max > pat.min {
			for _ in pat.min .. pat.max {
				cb.compile_0_or_1(mut c, macro)?
			}
		}
	} else {
		cb.compile_0_or_many(mut c, macro)?
	}
}

fn (mut cb MacroBE) compile_1(mut c Compiler, macro parser.MacroPattern) ? {
	match macro.name {
		"find" { cb.compile_find(mut c, macro.pat)? }
		else { return error("Unable to find implementation for macro/function: '$macro.name'") }
	}
}

fn (mut cb MacroBE) compile_0_or_many(mut c Compiler, macro parser.MacroPattern) ? {
	p1 := c.code.add_choice(0)
	p2 := c.code.len
	cb.compile_1(mut c, macro)?
	c.code.add_partial_commit(p2 - 2)
	c.code.update_addr(p1, c.code.len - 2)	// TODO +2, -2, need to fix this. There is some misunderstanding.
}

fn (mut cb MacroBE) compile_1_or_many(mut c Compiler, macro parser.MacroPattern) ? {
	cb.compile_1(mut c, macro)?
	cb.compile_0_or_many(mut c, macro)?
}

fn (mut cb MacroBE) compile_0_or_1(mut c Compiler, macro parser.MacroPattern) ? {
	p1 := c.code.add_choice(0)
	cb.compile_1(mut c, macro)?
	p2 := c.code.add_pop_choice(0)
	c.code.update_addr(p1, c.code.len - 2)	// TODO +2, -2, need to fix this. There is some misunderstanding.
	c.code.update_addr(p2, c.code.len - 2)	// TODO +2, -2, need to fix this. There is some misunderstanding.
}

fn (mut cb MacroBE) compile_find(mut c Compiler, pat parser.Pattern) ? {
	p1 := c.code.add_choice(0)
	c.compile_elem(pat, pat)?
	p2 := c.code.add_jmp(0)
	p3 := c.code.add_any()
	c.code.add_jmp(p1 - 2)
	c.code.update_addr(p1, p3 - 2)
	c.code.update_addr(p2, c.code.len - 2)
}
