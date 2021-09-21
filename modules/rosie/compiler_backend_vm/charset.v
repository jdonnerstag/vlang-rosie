module compiler_backend_vm

import rosie.runtime_v2 as rt
import rosie.parser


struct CharsetBE {}

fn (mut cb CharsetBE) compile(mut c Compiler, pat parser.Pattern, alias_pat parser.Pattern) ? {
	cs := (alias_pat.elem as parser.CharsetPattern).cs

	pred_p1 := c.predicate_pre(pat, 1)?

	cb.compile_inner(mut c, pat, cs)

	c.predicate_post(pat, pred_p1)
}

fn (mut cb CharsetBE) compile_inner(mut c Compiler, pat parser.Pattern, cs rt.Charset) {
	for _ in 0 .. pat.min {
		cb.compile_1(mut c, cs)
	}

	if pat.max != -1 {
		if pat.max > pat.min {
			cb.compile_0_to_n(mut c, cs, pat.max - pat.min)
		}
	} else {
		cb.compile_0_to_many(mut c, cs)
	}
}

fn (mut cb CharsetBE) compile_1(mut c Compiler, cs rt.Charset) {
	c.add_set(cs)
}

fn (mut cb CharsetBE) compile_0_to_many(mut c Compiler, cs rt.Charset) {
	c.add_span(cs)
}

fn (mut cb CharsetBE) compile_0_to_n(mut c Compiler, cs rt.Charset, max int) {
	mut ar := []int{ cap: max }
	for _ in 0 .. max {
		ar << c.add_test_set(cs, 0)
		c.add_any()
	}

	for pc in ar { c.update_addr(pc, c.code.len) }
}

fn (mut cb CharsetBE) compile_eof(mut c Compiler) {
	p1 := c.add_test_any(0)
	c.add_fail()
	c.update_addr(p1, c.code.len)
}
