module compiler_backend_vm

import rosie.parser


struct GroupBE {}

fn (mut cb GroupBE) compile(mut c Compiler, pat parser.Pattern, alias_pat parser.Pattern) ? {
	group := (alias_pat.elem as parser.GroupPattern)

	pat_len := group.input_len() or { 0 }
	pred_p1 := c.predicate_pre(pat, pat_len)?

	cb.compile_inner(mut c, pat, group)?

	c.predicate_post(pat, pred_p1)
}

fn (mut cb GroupBE) compile_inner(mut c Compiler, pat parser.Pattern, group parser.GroupPattern) ? {
	for _ in 0 .. pat.min {
		cb.compile_1(mut c, group)?
	}

	if pat.max != -1 {
		if pat.max > pat.min {
			cb.compile_0_to_n(mut c, group, pat.max - pat.min)?
		}
	} else {
		cb.compile_0_to_many(mut c, group)?
	}
}

fn (mut cb GroupBE) compile_1(mut c Compiler, group parser.GroupPattern) ? {
	for e in group.ar {
		c.compile_elem(e, e)?
	}
}

fn (mut cb GroupBE) compile_0_to_many(mut c Compiler, group parser.GroupPattern) ? {
	p1 := c.add_choice(0)
	cb.compile_1(mut c, group)?
	c.add_commit(p1)
	// TODO This can be optimized with partial commit
	c.update_addr(p1, c.code.len)
}

fn (mut cb GroupBE) compile_0_to_n(mut c Compiler, group parser.GroupPattern, max int) ? {
	mut ar := []int{ cap: max }
	for _ in 0 .. max {
		ar << c.add_choice(0)
		cb.compile_1(mut c, group)?
		p2 := c.add_commit(0)
		c.update_addr(p2, c.code.len)
		// TODO This can be optimized with partial commit
	}

	for pc in ar { c.update_addr(pc, c.code.len) }
}
