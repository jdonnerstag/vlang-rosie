module compiler_backend_vm

import rosie.parser


struct StringBE {
pub:
	pat parser.Pattern
	text string
}

fn (cb StringBE) compile(mut c Compiler) ? {
	mut x := DefaultPatternCompiler{
		pat: cb.pat,
		predicate_be: DefaultPredicateBE{ pat: cb.pat }
		compile_1_be: cb,
		compile_0_to_many_be: cb
	}

	x.compile(mut c) ?
}

fn (cb StringBE) compile_1(mut c Compiler) ? {
	for i := 0; i < cb.text.len; i++ {
		if (i + 3) < cb.text.len {
			a := unsafe { *&int(cb.text.str + i) }
			c.add_char_4(a)
			i += 3
		} else {
			ch := cb.text[i]
			c.add_char(ch)
		}
	}
}

fn (cb StringBE) compile_0_to_many(mut c Compiler) ? {
	p1 := c.add_choice(0)
	p2 := c.code.len
	cb.compile_1(mut c) ?
	c.add_partial_commit(p2)
	c.update_addr(p1, c.code.len)
}
