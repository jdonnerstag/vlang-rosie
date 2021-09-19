module compiler_backend_vm

import rosie.parser


struct DisjunctionBE {}

fn (mut cb DisjunctionBE) compile(mut c Compiler, pat parser.Pattern, alias_pat parser.Pattern) ? {
	group := (alias_pat.elem as parser.DisjunctionPattern)

	pat_len := group.input_len() or { 0 }
	pred_p1 := c.predicate_pre(pat, pat_len)?

	cb.compile_inner(mut c, pat, group)?

	c.predicate_post(pat, pred_p1)
}

fn (mut cb DisjunctionBE) compile_inner(mut c Compiler, pat parser.Pattern, group parser.DisjunctionPattern) ? {
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

fn (cb DisjunctionBE) close_choice(mut c Compiler, mut ar []int) {
	if ar.len > 0 {
		for p2 in ar { c.update_addr(p2, c.code.len) }
		ar.clear()
	}
}

fn (mut cb DisjunctionBE) compile_1(mut c Compiler, group parser.DisjunctionPattern) ? {
	mut ar := []int{}
	for i, e in group.ar {
		if (i + 1) == group.ar.len {
			c.compile_elem(e, e)?
		} else {
			p1 := c.add_choice(0)
			c.compile_elem(e, e)?
			ar << c.add_commit(0)
			c.update_addr(p1, c.code.len)
		}
	}

	cb.close_choice(mut c, mut ar)
}

fn (mut cb DisjunctionBE) compile_0_to_many(mut c Compiler, group parser.DisjunctionPattern) ? {
	p1 := c.add_choice(0)
	cb.compile_1(mut c, group)?
	c.add_commit(p1)
	// TODO This can be optimized with partial commit
	c.update_addr(p1, c.code.len)
}

fn (mut cb DisjunctionBE) compile_0_to_n(mut c Compiler, group parser.DisjunctionPattern, max int) ? {
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
