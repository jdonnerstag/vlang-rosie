module compiler_backend_vm

import rosie.parser


struct FindBE {}

// TODO Review wether really 2 patterns must be provided
fn (mut cb FindBE) compile(mut c Compiler, pat parser.Pattern, alias_pat parser.Pattern) ? {
	find_pat := (alias_pat.elem as parser.FindPattern)

	// TODO Not sure. Do we support predicates on 'find'
	pred_p1 := c.predicate_pre(pat, 1)?

	cb.compile_inner(mut c, pat, find_pat)?

	c.predicate_post(pat, pred_p1)
}

fn (mut cb FindBE) compile_inner(mut c Compiler, pat parser.Pattern, find_pat parser.FindPattern) ? {
	for _ in 0 .. pat.min {
		cb.compile_1(mut c, find_pat)?
	}

	if pat.max != -1 {
		if pat.max > pat.min {
			cb.compile_0_to_n(mut c, find_pat, pat.max - pat.min)?
		}
	} else {
		cb.compile_0_to_many(mut c, find_pat)?
	}
}

fn (mut cb FindBE) compile_1(mut c Compiler, find_pat parser.FindPattern) ? {
	a := parser.Pattern{ predicate: .negative_look_ahead, elem: parser.GroupPattern{ ar: [find_pat.pat] } }
	b := parser.Pattern{ elem: parser.NamePattern{ name: "." } }
	search_pat := parser.Pattern{ min: 0, max: -1, elem: parser.GroupPattern{ ar: [a, b] } }

	//eprintln("search_pat: ${search_pat.repr()}")
	if find_pat.keepto == false {
		c.compile_elem(search_pat, search_pat)?
	} else {
		c.add_open_capture("find:<search>")
		c.compile_elem(search_pat, search_pat)?
		c.add_close_capture()
	}

	x := parser.Pattern{ elem: parser.GroupPattern{ ar: [find_pat.pat] } }
	c.add_open_capture("find:*")
	c.compile_elem(x, x)?
	c.add_close_capture()
}

fn (mut cb FindBE) compile_0_to_many(mut c Compiler, find_pat parser.FindPattern) ? {
	p1 := c.add_choice(0)
	p2 := c.code.len
	cb.compile_1(mut c, find_pat)?
	c.add_partial_commit(p2)
	c.update_addr(p1, c.code.len)
}

fn (mut cb FindBE) compile_0_to_n(mut c Compiler, find_pat parser.FindPattern, max int) ? {
	mut ar := []int{ cap: max }
	for _ in 0 .. max {
		ar << c.add_choice(0)
		cb.compile_1(mut c, find_pat)?
		p2 := c.add_commit(0)
		c.update_addr(p2, c.code.len)
	}

	for pc in ar { c.update_addr(pc, c.code.len) }
}
