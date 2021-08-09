module compiler_backend_vm

import rosie.parser


struct AliasBE {}

fn (mut cb AliasBE) compile(mut c Compiler, pat parser.Pattern, name string) ? {
	mut pred_p1 := 0
	if pat.predicate == .negative_look_ahead {
		pred_p1 = c.code.add_choice(0)
	}

	binding := c.parser.binding_(name)?
	cb.compile_inner(mut c, pat, binding)?

	if pat.predicate == .negative_look_ahead {
		c.code.add_fail_twice()
		c.code.update_addr(pred_p1, c.code.len - 2)
	}
}

fn (mut cb AliasBE) compile_inner(mut c Compiler, pat parser.Pattern, binding parser.Binding) ? {
	for _ in 0 .. pat.min {
		cb.compile_1(mut c, binding)?
	}

	if pat.max != -1 {
		if pat.max > pat.min {
			for _ in pat.min .. pat.max {
				cb.compile_0_or_1(mut c, binding)?
			}
		}
	} else {
		cb.compile_0_or_many(mut c, binding)?
	}
}

fn (mut cb AliasBE) compile_1(mut c Compiler, binding parser.Binding) ? {
	if binding.alias == false {
		idx := c.symbols.find(binding.name) or {
			c.symbols.add(binding.name)
			c.symbols.len()
		}
		c.code.add_open_capture(idx)
	}

	c.compile_elem(binding.pattern, binding.pattern)?

	if binding.alias == false {
		c.code.add_close_capture()
	}
}

fn (mut cb AliasBE) compile_0_or_many(mut c Compiler, binding parser.Binding) ? {
	p1 := c.code.add_choice(0)
	p2 := c.code.len
	cb.compile_1(mut c, binding)?
	c.code.add_partial_commit(p2 - 2)
	c.code.update_addr(p1, c.code.len - 2)	// TODO +2, -2, need to fix this. There is some misunderstanding.
}

fn (mut cb AliasBE) compile_1_or_many(mut c Compiler, binding parser.Binding) ? {
	cb.compile_1(mut c, binding)?
	cb.compile_0_or_many(mut c, binding)?
}

fn (mut cb AliasBE) compile_0_or_1(mut c Compiler, binding parser.Binding) ? {
	p1 := c.code.add_choice(0)
	cb.compile_1(mut c, binding)?
	p2 := c.code.add_pop_choice(0)
	c.code.update_addr(p1, c.code.len - 2)	// TODO +2, -2, need to fix this. There is some misunderstanding.
	c.code.update_addr(p2, c.code.len - 2)	// TODO +2, -2, need to fix this. There is some misunderstanding.
}
