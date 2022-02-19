module vm_v2

import rosie


struct StringBE {
pub:
	pat rosie.Pattern
	text string
}

fn (cb StringBE) compile(mut c Compiler) ? {
	// Optimization: ab optional char
	// TODO apply to charset as well
	if cb.text.len == 1 {
		if cb.pat.min == 0 && cb.pat.max == 1 {
			cb.compile_optional_char(mut c, cb.text[0])
			return
		}
	}

	mut x := DefaultPatternCompiler{
		pat: cb.pat,
		predicate_be: DefaultPredicateBE{ pat: cb.pat }
		compile_1_be: cb,
		compile_0_to_many_be: cb
	}

	x.compile(mut c) ?
}

fn (cb StringBE) compile_1(mut c Compiler) ? {
	if cb.text.len < 4 {
		for ch in cb.text {
			c.add_char(ch)
		}
	} else {
		c.add_str(cb.text)
	}
}

fn (cb StringBE) compile_0_to_many(mut c Compiler) ? {
	p1 := c.add_choice(0)
	p2 := c.rplx.code.len
	cb.compile_1(mut c) ?
	c.add_partial_commit(p2)
	c.update_addr(p1, c.rplx.code.len)
}

fn (cb StringBE) compile_optional_char(mut c Compiler, ch byte) {
	p1 := c.add_test_char(ch, 0)
	c.add_any()
	c.update_addr(p1, c.rplx.code.len)
}
