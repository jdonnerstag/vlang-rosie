module compiler_backend_vm

import rosie.runtime_v2 as rt
import rosie.parser

enum CharsetBEOptimizations {
	standard
	few_chars
	bit_7
}

struct CharsetBE {
mut:
	optimization CharsetBEOptimizations = .standard
	count int
pub:
	pat parser.Pattern
	cs rt.Charset
}

fn (mut cb CharsetBE) compile(mut c Compiler) ? {
	if cb.cs.is_equal(rt.known_charsets["ascii"]) {
		cb.optimization = .bit_7
	} else {
		count, _ := cb.cs.count()
		if count < 5 || count > 251 {
			cb.optimization = .few_chars
			cb.count = count
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

fn (cb CharsetBE) compile_1(mut c Compiler) ? {
	if cb.optimization == .bit_7 {
		c.add_bit_7()
		return
	}

	if cb.optimization == .few_chars {
		complement := cb.count > 100
		cs := if complement { cb.cs.complement() } else { cb.cs }

		mut ar := []int{}
		for i in 0 .. C.UCHAR_MAX {
			if cs.testchar(byte(i)) {
				ar << c.add_if_char(byte(i), 0)
			}
		}

		if complement == false {
			c.add_fail()
			for p1 in ar { c.update_addr(p1, c.code.len) }
		} else {
			p1 := c.add_jmp(0)
			for p2 in ar { c.update_addr(p2, c.code.len) }
			c.add_fail()
			c.update_addr(p1, c.code.len)
			c.add_any()
		}

		return
	}

	c.add_set(cb.cs)
}

fn (cb CharsetBE) compile_0_to_many(mut c Compiler) ? {
	c.add_span(cb.cs)
}
