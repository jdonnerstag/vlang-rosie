module v3

import rosie


struct DisjunctionBE {
pub:
	pat rosie.Pattern
	elem rosie.DisjunctionPattern
}


fn (cb DisjunctionBE) compile(mut c Compiler) ? {
	mut x := DefaultPatternCompiler{
		pat: cb.pat,
		predicate_be: DefaultPredicateBE{ pat: cb.pat },
		compile_1_be: cb,
		compile_0_to_many_be: DefaultCompile_0_to_many{ pat: cb.pat, compile_1_be: cb }
	}

	x.compile(mut c) ?
}

fn (cb DisjunctionBE) compile_1(mut c Compiler) ? {
	group := cb.elem
	if group.negative == false {
		mut ar := []int{}
		for i, e in group.ar {
			if (i + 1) == group.ar.len {
				c.compile_elem(e, e)?
			} else {
				// Some pattern can be performance optimized by avoiding .choice
				// TODO Identify additional pattern that may benefit from it. Charsets?
				if e.elem is rosie.LiteralPattern {
					str := e.elem.text
					if str.len > 0 {
						ar << c.add_if_str(str, 0)
					}
				} else {
					p1 := c.add_choice(0)
					c.compile_elem(e, e)?
					ar << c.add_commit(0)
					c.update_addr(p1, c.rplx.code.len)
				}
			}
		}

		for p2 in ar { c.update_addr(p2, c.rplx.code.len) }
	} else {
		for e in group.ar {
			p1 := c.add_choice(0)
			c.compile_elem(e, e)?
			p2 := c.add_commit(0)
			p3 := c.add_fail()
			c.update_addr(p2, p3)
			c.update_addr(p1, c.rplx.code.len)
		}

		c.add_any()
	}
}
