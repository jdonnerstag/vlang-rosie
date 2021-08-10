module compiler_backend_vm

import rosie.parser


struct StringBE {}

fn (mut cb StringBE) compile(mut c Compiler, pat parser.Pattern, str string) {
	mut pred_p1 := 0
	if pat.predicate == .negative_look_ahead {
		pred_p1 = c.code.add_choice(0)
	} else if pat.predicate == .look_ahead {
		// nothing
	} else if pat.predicate == .look_behind {
		pred_p1 = c.code.add_choice(0)
		c.code.add_behind(str.len)
	} else if pat.predicate == .negative_look_behind {
		pred_p1 = c.code.add_choice(0)
		c.code.add_behind(str.len)
	}

	cb.compile_inner(mut c, pat, str)

	if pat.predicate == .negative_look_ahead {
		c.code.add_fail_twice()
		c.code.update_addr(pred_p1, c.code.len - 2)
	} else if pat.predicate == .look_ahead {
		c.code.add_reset_pos()
	} else if pat.predicate == .look_behind {
		p2 := c.code.add_jmp(0)
		p3 := c.code.add_fail()
		c.code.update_addr(p2, c.code.len - 2)
		c.code.update_addr(pred_p1, p3 - 2)
	} else if pat.predicate == .negative_look_behind {
		c.code.add_fail_twice()
		c.code.update_addr(pred_p1, c.code.len - 2)
	}
}

fn (mut cb StringBE) compile_inner(mut c Compiler, pat parser.Pattern, str string) {
	for _ in 0 .. pat.min {
		cb.compile_1(mut c, str)
	}

	if pat.max != -1 {
		if pat.max > pat.min {
			for _ in pat.min .. pat.max {
				cb.compile_0_or_1(mut c, str)
			}
		}
	} else {
		cb.compile_0_or_many(mut c, str)
	}
}

fn (mut cb StringBE) compile_1(mut c Compiler, str string) {
	for ch in str {
		c.code.add_char(ch)
	}
}

fn (mut cb StringBE) compile_0_or_many(mut c Compiler, str string) {
	p1 := c.code.add_choice(0)
	p2 := c.code.len
	cb.compile_1(mut c, str)
	c.code.add_partial_commit(p2 - 2)
	c.code.update_addr(p1, c.code.len - 2)
}

fn (mut cb StringBE) compile_1_or_many(mut c Compiler, str string) {
	cb.compile_1(mut c, str)
	cb.compile_0_or_many(mut c, str)
}

fn (mut cb StringBE) compile_0_or_1(mut c Compiler, str string) {
	p1 := c.code.add_choice(0)
	cb.compile_1(mut c, str)
	p2 := c.code.add_pop_choice(0)
	c.code.update_addr(p1, c.code.len - 2)	// TODO +2, -2, need to fix this. There is some misunderstanding.
	c.code.update_addr(p2, c.code.len - 2)	// TODO +2, -2, need to fix this. There is some misunderstanding.
}
