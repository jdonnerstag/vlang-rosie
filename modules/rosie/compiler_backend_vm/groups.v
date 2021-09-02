module compiler_backend_vm

import rosie.parser


struct GroupBE {}

fn (mut cb GroupBE) compile(mut c Compiler, pat parser.Pattern, alias_pat parser.Pattern) ? {
	group := (alias_pat.elem as parser.GroupPattern)

	pat_len := pat.input_len() or { 0 }
	pred_p1 := c.predicate_pre(pat, pat_len)

	cb.compile_inner(mut c, pat, group)?

	c.predicate_post(pat, pred_p1)
}

fn (mut cb GroupBE) compile_inner(mut c Compiler, pat parser.Pattern, group parser.GroupPattern) ? {
	add_word_boundary := group.word_boundary == true && (pat.max > 1 || pat.max == -1)

	for i in 0 .. pat.min {
		cb.compile_1(mut c, group, i > 0 && add_word_boundary)?
	}

	if pat.max != -1 {
		if pat.max > pat.min {
			cb.compile_0_to_n(mut c, group, pat.max - pat.min, add_word_boundary)?
		}
	} else {
		cb.compile_0_to_many(mut c, group, add_word_boundary)?
	}
}

fn (cb GroupBE) close_choice(mut c Compiler, mut ar []int) {
	if ar.len > 0 {
		for p2 in ar { c.update_addr(p2, c.code.len) }
		ar.clear()
	}
}

fn (mut cb GroupBE) add_word_boundary(mut c Compiler) ? {
	pat := parser.Pattern{ word_boundary: false, elem: parser.NamePattern{ text: "~" }}
	c.compile_elem(pat, pat)?
}

fn (mut cb GroupBE) compile_1(mut c Compiler, group parser.GroupPattern, add_word_boundary bool) ? {
	if add_word_boundary == true { cb.add_word_boundary(mut c)? }

	mut ar := []int{}
	for i, e in group.ar {
		if e.operator == .sequence || (i + 1) == group.ar.len {
			c.compile_elem(e, e)?

			// TODO Not sure the index test is necessary
			if (i + 1) < group.ar.len && e.word_boundary { cb.add_word_boundary(mut c)? }

			cb.close_choice(mut c, mut ar)
		} else if e.operator == .choice  {
			p1 := c.add_choice(0)
			c.compile_elem(e, e)?
			ar << c.add_commit(0)
			c.update_addr(p1, c.code.len)
		} else {
			panic("GroupBE: compile_1: unsupported construct: ${group.repr()}")
		}
	}

	cb.close_choice(mut c, mut ar)
}

fn (mut cb GroupBE) compile_0_to_many(mut c Compiler, group parser.GroupPattern, add_word_boundary bool) ? {
	p1 := c.add_choice(0)
	p2 := c.code.len
	cb.compile_1(mut c, group, add_word_boundary)?
	c.add_partial_commit(p2)
	c.update_addr(p1, c.code.len)
}

fn (mut cb GroupBE) compile_0_to_n(mut c Compiler, group parser.GroupPattern, max int, add_word_boundary bool) ? {
	mut ar := []int{ cap: max }
	for i in 0 .. max {
		ar << c.add_choice(0)
		cb.compile_1(mut c, group, i > 0 && add_word_boundary)?
		p2 := c.add_commit(0)
		c.update_addr(p2, c.code.len)
	}

	for pc in ar { c.update_addr(pc, c.code.len) }
}
