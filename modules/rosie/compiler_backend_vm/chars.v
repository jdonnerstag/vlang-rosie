module compiler_backend_vm

import rosie.runtime_v2 as rt
import rosie.parser


struct CharBE {}

fn (mut cb CharBE) compile(mut c Compiler, pat parser.Pattern, alias_pat parser.Pattern) ? {
	ch := (alias_pat.elem as parser.LiteralPattern).text[0]

	pred_p1 := c.predicate_pre(pat, 1)?

	cb.compile_inner(mut c, pat, ch)

	c.predicate_post(pat, pred_p1)
}

fn (mut cb CharBE) compile_inner(mut c Compiler, pat parser.Pattern, ch byte) {
	for _ in 0 .. pat.min {
		cb.compile_1(mut c, ch)
	}

	if pat.max != -1 {
		if pat.max > pat.min {
			cb.compile_0_to_n(mut c, ch, pat.max - pat.min)
		}
	} else {
		cb.compile_0_to_many(mut c, ch)
	}
}

fn (mut cb CharBE) compile_1(mut c Compiler, ch byte) {
	c.add_char(ch)
}

fn (mut cb CharBE) compile_0_to_many(mut c Compiler, ch byte) {
	cs := rt.new_charset_with_byte(ch)
	c.add_span(cs)
}

fn (mut cb CharBE) compile_0_to_n(mut c Compiler, ch byte, max int) {
	mut ar := []int{ cap: max }
	for _ in 0 .. max {
		ar << c.add_test_char(ch, 0)
		c.add_any()
	}

	for pc in ar { c.update_addr(pc, c.code.len) }
}
