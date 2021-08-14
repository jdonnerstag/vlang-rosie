module compiler_backend_vm

import rosie.runtime_v2 as rt
import rosie.parser


struct CharBE {}

fn (mut cb CharBE) compile(mut c Compiler, pat parser.Pattern, alias_pat parser.Pattern) ? {
	ch := (alias_pat.elem as parser.LiteralPattern).text[0]

	pred_p1 := c.predicate_pre(pat, 1)

	cb.compile_inner(mut c, pat, ch)

	c.predicate_post(pat, pred_p1)
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

fn (mut cb CharBE) to_case_insensitive(ch byte) rt.Charset {
	lower := ch.ascii_str().to_lower()[0]
	upper := ch.ascii_str().to_upper()[0]

	mut cs := rt.new_charset_with_byte(lower)
	cs.set_char(upper)

	return cs
}

fn (mut cb CharBE) compile_1(mut c Compiler, ch byte) {
	if c.case_insensitive {
		cs := cb.to_case_insensitive(ch)
		c.add_set(cs)
	} else {
		c.add_char(ch)
	}
}

fn (mut cb CharBE) compile_0_or_many(mut c Compiler, ch byte) {
	cs := if c.case_insensitive {
		cb.to_case_insensitive(ch)
	} else {
		rt.new_charset_with_byte(ch)
	}
	c.add_span(cs)
}

fn (mut cb CharBE) compile_1_or_many(mut c Compiler, ch byte) {
	cb.compile_1(mut c, ch)
	cb.compile_0_or_many(mut c, ch)
}

fn (mut cb CharBE) compile_0_or_1(mut c Compiler, ch byte) {
	p1 := if c.case_insensitive {
		cs := cb.to_case_insensitive(ch)
		c.add_test_set(cs, 0)
	} else {
		c.add_test_char(ch, 0)
	}

	c.add_any()
	c.update_addr(p1, c.code.len)
}
