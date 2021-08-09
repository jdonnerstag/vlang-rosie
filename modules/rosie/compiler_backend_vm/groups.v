module compiler_backend_vm

import rosie.parser


struct GroupBE {}

fn (mut cb GroupBE) compile(mut c Compiler, pat parser.Pattern, group parser.GroupPattern) ? {
	mut pred_p1 := 0
	if pat.predicate == .negative_look_ahead {
		pred_p1 = c.code.add_choice(0)
	}

	cb.compile_inner(mut c, pat, group)?

	if pat.predicate == .negative_look_ahead {
		c.code.add_fail_twice()
		c.code.update_addr(pred_p1, c.code.len - 2)
	}
}

fn (mut cb GroupBE) compile_inner(mut c Compiler, pat parser.Pattern, group parser.GroupPattern) ? {
	for _ in 0 .. pat.min {
		cb.compile_1(mut c, group)?
	}

	if pat.max != -1 {
		if pat.max > pat.min {
			for _ in pat.min .. pat.max {
				cb.compile_0_or_1(mut c, group)?
			}
		}
	} else {
		cb.compile_0_or_many(mut c, group)?
	}
}

fn (cb GroupBE) update_addr_ar(mut c Compiler, mut ar []int, pos int) {
	for p2 in ar {
		c.code.update_addr(p2, c.code.len - 2)
	}
	ar.clear()
}

fn (mut cb GroupBE) compile_1(mut c Compiler, group parser.GroupPattern) ? {
	mut ar := []int{}

	for e in group.ar {
		if e.operator == .sequence {
			c.compile_elem(e, e)?

			if ar.len > 0 {
				c.code.add_fail()
				cb.update_addr_ar(mut c, mut ar, c.code.len - 2)
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
		cb.update_addr_ar(mut c, mut ar, c.code.len - 2)
	}
}

fn (mut cb GroupBE) compile_0_or_many(mut c Compiler, group parser.GroupPattern) ? {
	p1 := c.code.add_choice(0)
	p2 := c.code.len
	cb.compile_1(mut c, group)?
	c.code.add_jmp(p2 - 2)
	c.code.add_pop_choice(0)
	c.code.update_addr(p1, c.code.len - 2)	// TODO +2, -2, need to fix this. There is some misunderstanding.
	c.code.update_addr(p2, c.code.len - 2)	// TODO +2, -2, need to fix this. There is some misunderstanding.
}

fn (mut cb GroupBE) compile_1_or_many(mut c Compiler, group parser.GroupPattern) ? {
	cb.compile_1(mut c, group)?
	cb.compile_0_or_many(mut c, group)?
}

fn (mut cb GroupBE) compile_0_or_1(mut c Compiler, group parser.GroupPattern) ? {
	p1 := c.code.add_choice(0)
	cb.compile_1(mut c, group)?
	p2 := c.code.add_pop_choice(0)
	c.code.update_addr(p1, c.code.len - 2)	// TODO +2, -2, need to fix this. There is some misunderstanding.
	c.code.update_addr(p2, c.code.len - 2)	// TODO +2, -2, need to fix this. There is some misunderstanding.
}
