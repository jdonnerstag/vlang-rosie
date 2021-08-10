module compiler_backend_vm

import rosie.runtime as rt
import rosie.parser


struct CharBE {}

fn (mut cb CharBE) compile(mut c Compiler, pat parser.Pattern, alias_pat parser.Pattern) ? {
	ch := (alias_pat.elem as parser.LiteralPattern).text[0]

	mut pred_p1 := 0
	if pat.predicate == .negative_look_ahead {
		pred_p1 = c.code.add_choice(0)
	}

	cb.compile_inner(mut c, pat, ch)

	if pat.predicate == .negative_look_ahead {
		c.code.add_fail_twice()
		c.code.update_addr(pred_p1, c.code.len - 2)
	}
}

fn (mut cb CharBE) compile_inner(mut c Compiler, pat parser.Pattern, ch byte) {
	for _ in 0 .. pat.min {
		cb.compile_1(mut c, ch)
	}

	if pat.max != -1 {
		if pat.max > pat.min {
			for _ in pat.min .. pat.max {
				cb.compile_0_or_1(mut c, ch)
			}
		}
	} else {
		cb.compile_0_or_many(mut c, ch)
	}
}

fn (mut cb CharBE) compile_1(mut c Compiler, ch byte) {
	c.code.add_char(ch)
}

fn (mut cb CharBE) compile_0_or_many(mut c Compiler, ch byte) {
	c.code.add_span(rt.new_charset_with_byte(ch))
}

fn (mut cb CharBE) compile_1_or_many(mut c Compiler, ch byte) {
	c.code.add_char(ch)
	c.code.add_span(rt.new_charset_with_byte(ch))
}

fn (mut cb CharBE) compile_0_or_1(mut c Compiler, ch byte) {
	p1 := c.code.add_test_char(ch, 0)
	c.code.add_any()
	c.code.update_addr(p1, c.code.len - 2)
}
