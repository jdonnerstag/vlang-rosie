module compiler_backend_vm

import rosie.runtime_v2 as rt
import rosie.parser


struct CharsetBE {}

fn (mut cb CharsetBE) compile(mut c Compiler, pat parser.Pattern, alias_pat parser.Pattern) ? {
	cs := (alias_pat.elem as parser.CharsetPattern).cs

	pred_p1 := c.predicate_pre(pat, 1)

	cs1 := if c.case_insensitive { cs.to_case_insensitive() } else { cs }
	cb.compile_inner(mut c, pat, cs1)

	c.predicate_post(pat, pred_p1)

	if cs.must_be_eof { cb.compile_eof(mut c) }
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
	c.code.add_set(cs)
}

fn (mut cb CharsetBE) compile_0_or_many(mut c Compiler, cs rt.Charset) {
	c.code.add_span(cs)
}

fn (mut cb CharsetBE) compile_1_or_many(mut c Compiler, cs rt.Charset) {
	cb.compile_1(mut c, cs)
	cb.compile_0_or_many(mut c, cs)
}

fn (mut cb CharsetBE) compile_0_or_1(mut c Compiler, cs rt.Charset) {
	p1 := c.code.add_test_set(cs, 0)
	c.code.add_any()
	c.code.update_addr(p1, c.code.len)
}

fn (mut cb CharsetBE) compile_eof(mut c Compiler) {
	p1 := c.code.add_test_any(0)
	c.code.add_fail()
	c.code.update_addr(p1, c.code.len)
}
