module vm_v2

import rosie


struct EofBE {
pub:
	pat rosie.Pattern
	eof bool
}

fn (cb EofBE) compile(mut c Compiler) ? {
	mut x := DefaultPatternCompiler{
		pat: cb.pat,
		predicate_be: DefaultPredicateBE{ pat: cb.pat },
		compile_1_be: cb,
		compile_0_to_many_be: DefaultCompile_0_to_many{ pat: cb.pat, compile_1_be: cb }
	}

	x.compile(mut c)?
}

fn (cb EofBE) compile_1(mut c Compiler) ? {
	if cb.eof {
		p1 := c.add_test_any(0)
		c.add_fail()
		c.update_addr(p1, c.rplx.code.len)
	} else {
		p1 := c.add_choice(0)
		c.add_behind(1)
		c.add_fail_twice()
		c.update_addr(p1, c.rplx.code.len)
	}
}
