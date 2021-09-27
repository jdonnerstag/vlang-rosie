module compiler_backend_vm

import rosie.parser


struct DisjunctionBE {}

fn (cb DisjunctionBE) compile(mut c Compiler, pat parser.Pattern, group parser.DisjunctionPattern) ? {
	pat_len := group.input_len() or { 0 }
	pred_p1 := c.predicate_pre(pat, pat_len)?

	cb.compile_inner(mut c, pat, group)?

	c.predicate_post(pat, pred_p1)
}

fn (cb DisjunctionBE) compile_inner(mut c Compiler, pat parser.Pattern, group parser.DisjunctionPattern) ? {
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

fn (cb DisjunctionBE) compile_1(mut c Compiler, group parser.DisjunctionPattern) ? {
	if group.negative == false {
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

		for p2 in ar { c.update_addr(p2, c.code.len) }
	} else {
		for e in group.ar {
			p1 := c.add_choice(0)
			c.compile_elem(e, e)?
			p2 := c.add_commit(0)	// TODO could we use back_commit instead?
			p3 := c.add_fail()
			c.update_addr(p2, p3)
			c.update_addr(p1, c.code.len)
		}

		c.add_any()
	}
}

fn (cb DisjunctionBE) compile_0_to_many(mut c Compiler, group parser.DisjunctionPattern) ? {
	// TODO Would it possible leverage partial_commit and avoid excessive push / pop?
	p1 := c.add_choice(0)
	cb.compile_1(mut c, group)?
	c.add_commit(p1)
	c.update_addr(p1, c.code.len)
}

fn (cb DisjunctionBE) compile_0_to_n(mut c Compiler, group parser.DisjunctionPattern, max int) ? {
	mut ar := []int{ cap: max }
	for _ in 0 .. max {
		ar << c.add_choice(0)
		cb.compile_1(mut c, group)?
		p2 := c.add_commit(0)
		c.update_addr(p2, c.code.len)
		// TODO I thik this can be optimized with partial commit
	}

	for pc in ar { c.update_addr(pc, c.code.len) }
}
