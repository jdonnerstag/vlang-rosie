module compiler_backend_vm

import rosie.runtime as rt
import rosie.parser


struct CharsetBE {}

fn (mut cb CharsetBE) compile(mut c Compiler, pat parser.Pattern, cs rt.Charset) {
	mut pred_p1 := 0
	if pat.predicate == .negative_look_ahead {
		pred_p1 = c.code.add_choice(0)
	}

	cb.compile_inner(mut c, pat, cs)

	if pat.predicate == .negative_look_ahead {
		c.code.add_fail_twice()
		c.code.update_addr(pred_p1, c.code.len - 2)
	}
}

fn (mut cb CharsetBE) compile_inner(mut c Compiler, pat parser.Pattern, cs rt.Charset) {
	for _ in 0 .. pat.min {
		cb.compile_1(mut c, cs)
	}

	if pat.max != -1 {
		if pat.max > pat.min {
			for _ in pat.min .. pat.max {
				cb.compile_0_or_1(mut c, cs)
			}
		}
	} else {
		cb.compile_0_or_many(mut c, cs)
	}
}

fn (mut cb CharsetBE) compile_1(mut c Compiler, cs rt.Charset) {
	eprintln("${@FN}")
	c.code.add_set(cs)
}

fn (mut cb CharsetBE) compile_0_or_many(mut c Compiler, cs rt.Charset) {
	eprintln("${@FN}")
	c.code.add_span(cs)
}

fn (mut cb CharsetBE) compile_1_or_many(mut c Compiler, cs rt.Charset) {
	eprintln("${@FN}")
	c.code.add_set(cs)
	c.code.add_span(cs)
}

fn (mut cb CharsetBE) compile_0_or_1(mut c Compiler, cs rt.Charset) {
	eprintln("${@FN}")
	p1 := c.code.add_test_set(cs, 0)
	c.code.add_any()
	c.code.update_addr(p1, c.code.len - 2)
}
