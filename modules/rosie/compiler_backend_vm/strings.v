module compiler_backend_vm

import rosie.parser
import rosie.runtime_v2 as rt


struct StringBE {}

fn (mut cb StringBE) compile(mut c Compiler, pat parser.Pattern, alias_pat parser.Pattern) ? {
	str := (pat.elem as parser.LiteralPattern).text

	pred_p1 := c.predicate_pre(pat, str.len)

	cb.compile_inner(mut c, pat, str)

	c.predicate_post(pat, pred_p1)
}

fn (mut cb StringBE) compile_inner(mut c Compiler, pat parser.Pattern, str string) {
	for _ in 0 .. pat.min {
		cb.compile_1(mut c, str)
	}

	if pat.max != -1 {
		if pat.max > pat.min {
			cb.compile_0_to_n(mut c, str, pat.max - pat.min)
		}
	} else {
		cb.compile_0_to_many(mut c, str)
	}
}

fn (mut cb StringBE) to_case_insensitive(ch byte) rt.Charset {
	lower := ch.ascii_str().to_lower()[0]
	upper := ch.ascii_str().to_upper()[0]

	mut cs := rt.new_charset_with_byte(lower)
	cs.set_char(upper)

	return cs
}

fn (mut cb StringBE) compile_1(mut c Compiler, str string) {
	for ch in str {
		if c.case_insensitive {
			cs := cb.to_case_insensitive(ch)
			c.add_set(cs)
		} else {
			c.add_char(ch)
		}
	}
}

fn (mut cb StringBE) compile_0_to_many(mut c Compiler, str string) {
	p1 := c.add_choice(0)
	p2 := c.code.len
	cb.compile_1(mut c, str)
	c.add_partial_commit(p2)
	c.update_addr(p1, c.code.len)
}

fn (mut cb StringBE) compile_0_to_n(mut c Compiler, str string, max int) {
	mut ar := []int{ cap: max }
	for _ in 0 .. max {
		ar << c.add_choice(0)
		cb.compile_1(mut c, str)
		p2 := c.add_commit(0)
		c.update_addr(p2, c.code.len)
	}

	for pc in ar { c.update_addr(pc, c.code.len) }
}
