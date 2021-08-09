module compiler_backend_vm

import rosie.parser


struct AliasBE {}

fn (mut cb AliasBE) compile(mut c Compiler, pat parser.Pattern, name string) ? {
	mut pred_p1 := 0
	if pat.predicate == .negative_look_ahead {
		pred_p1 = c.code.add_choice(0)
	}

	cb.compile_inner(mut c, pat, name)?

	if pat.predicate == .negative_look_ahead {
		c.code.add_fail_twice()
		c.code.update_addr(pred_p1, c.code.len - 2)
	}
}

fn (mut cb AliasBE) compile_inner(mut c Compiler, pat parser.Pattern, name string) ? {
	for _ in 0 .. pat.min {
		cb.compile_1(mut c, name)?
	}

	if pat.max != -1 {
		if pat.max > pat.min {
			for _ in pat.min .. pat.max {
				cb.compile_0_or_1(mut c, name)?
			}
		}
	} else {
		cb.compile_0_or_many(mut c, name)?
	}
}

fn (mut cb AliasBE) compile_1(mut c Compiler, name string) ? {
	b := c.parser.binding_(name)?
	if b.alias == false {
		idx := c.symbols.find(name) or {
			c.symbols.add(name)
			c.symbols.len()
		}
		c.code.add_open_capture(idx)
	}

	c.compile_elem(b.pattern, b.pattern)?

	if b.alias == false {
		c.code.add_close_capture()
	}
}

fn (mut cb AliasBE) compile_0_or_many(mut c Compiler, name string) ? {
	p1 := c.code.add_choice(0)
	p2 := c.code.len
	cb.compile_1(mut c, name)?
	c.code.add_jmp(p2 - 2)
	c.code.add_pop_choice(0)
	c.code.update_addr(p1, c.code.len - 2)	// TODO +2, -2, need to fix this. There is some misunderstanding.
	c.code.update_addr(p2, c.code.len - 2)	// TODO +2, -2, need to fix this. There is some misunderstanding.
}

fn (mut cb AliasBE) compile_1_or_many(mut c Compiler, name string) ? {
	cb.compile_1(mut c, name)?
	cb.compile_0_or_many(mut c, name)?
}

fn (mut cb AliasBE) compile_0_or_1(mut c Compiler, name string) ? {
	p1 := c.code.add_choice(0)
	cb.compile_1(mut c, name)?
	p2 := c.code.add_pop_choice(0)
	c.code.update_addr(p1, c.code.len - 2)	// TODO +2, -2, need to fix this. There is some misunderstanding.
	c.code.update_addr(p2, c.code.len - 2)	// TODO +2, -2, need to fix this. There is some misunderstanding.
}
