module compiler_backend_vm

import rosie.parser


struct GroupBE {}

fn (mut cb GroupBE) compile(mut c Compiler, pat parser.Pattern, alias_pat parser.Pattern) ? {
	group := (alias_pat.elem as parser.GroupPattern)

	pred_p1 := c.predicate_pre(pat, 0)	// look-behind is not supported with groups

	cb.compile_inner(mut c, pat, group)?

	c.predicate_post(pat, pred_p1)
}

fn (mut cb GroupBE) compile_inner(mut c Compiler, pat parser.Pattern, group parser.GroupPattern) ? {
	add_word_boundary := pat.max > 1 || pat.max == -1

	for _ in 0 .. pat.min {
		cb.compile_1(mut c, group, add_word_boundary)?
	}

	if pat.max != -1 {
		if pat.max > pat.min {
			for _ in pat.min .. pat.max {
				cb.compile_0_or_1(mut c, group, add_word_boundary)?
			}
		}
	} else {
		cb.compile_0_or_many(mut c, group, add_word_boundary)?
	}
}

fn (cb GroupBE) update_addr_ar(mut c Compiler, mut ar []int, pos int) {
	for p2 in ar {
		c.code.update_addr(p2, c.code.len)
	}
	ar.clear()
}

fn (mut cb GroupBE) compile_1(mut c Compiler, group parser.GroupPattern, add_word_boundary bool) ? {
	mut ar := []int{}
	for i, e in group.ar {
		if e.operator == .choice || (i > 0 && group.ar[i - 1].operator == .choice) {
			// Wrap every choice ...
			p1 := c.code.add_choice(0)
			c.compile_elem(e, e)?
			p2 := c.code.add_commit(0)	// pop the entry added by choice
			ar << p2
			c.code.update_addr(p1, c.code.len)
		} else {
			// End of choices
			if ar.len > 0 {
				c.code.add_fail()
				cb.update_addr_ar(mut c, mut ar, c.code.len)
			}

			if i > 0 {
				last := group.ar[i - 1]
				//eprintln("last=$last")
				if last.word_boundary == true && last.elem !is parser.GroupPattern
					&& last.elem !is parser.EofPattern && e.elem !is parser.EofPattern
				{
					//eprintln("insert word bounday: ${group.ar[i - 1].repr()} <=> ${e.repr()}")
					pat := c.parser.pattern("~")?
					c.compile_elem(pat, pat)?
				}
			}

			c.compile_elem(e, e)?
		}
	}

	if ar.len > 0 {
		c.code.add_fail()
		cb.update_addr_ar(mut c, mut ar, c.code.len)
	}

	if group.word_boundary && add_word_boundary {
		pat := c.parser.pattern("~")?
		c.compile_elem(pat, pat)?
	}
}

fn (mut cb GroupBE) compile_0_or_many(mut c Compiler, group parser.GroupPattern, add_word_boundary bool) ? {
	p1 := c.code.add_choice(0)
	p2 := c.code.len
	cb.compile_1(mut c, group, add_word_boundary)?
	c.code.add_partial_commit(p2)
	c.code.update_addr(p1, c.code.len)
}

fn (mut cb GroupBE) compile_1_or_many(mut c Compiler, group parser.GroupPattern, add_word_boundary bool) ? {
	cb.compile_1(mut c, group, add_word_boundary)?
	cb.compile_0_or_many(mut c, group, add_word_boundary)?
}

fn (mut cb GroupBE) compile_0_or_1(mut c Compiler, group parser.GroupPattern, add_word_boundary bool) ? {
	p1 := c.code.add_choice(0)
	cb.compile_1(mut c, group, add_word_boundary)?
	p2 := c.code.add_commit(0)
	c.code.update_addr(p1, c.code.len)
	c.code.update_addr(p2, c.code.len)
}
