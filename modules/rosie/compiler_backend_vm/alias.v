module compiler_backend_vm

import rosie.parser


struct AliasBE {}

fn (mut cb AliasBE) compile(mut c Compiler, pat parser.Pattern, alias_pat parser.Pattern) ? {
	name := (alias_pat.elem as parser.NamePattern).text

	pred_p1 := c.predicate_pre(pat, 0)	// look-behind is not supported

	binding := c.binding(name)?

	pkg := c.pkg_fpath
	defer { c.pkg_fpath = pkg }
	c.pkg_fpath = binding.fpath

	cb.compile_inner(mut c, pat, binding)?

	c.predicate_post(pat, pred_p1)
}

fn (mut cb AliasBE) compile_inner(mut c Compiler, pat parser.Pattern, binding parser.Binding) ? {
	for _ in 0 .. pat.min {
		cb.compile_1(mut c, binding)?
	}

	if pat.max != -1 {
		if pat.max > pat.min {
			for _ in pat.min .. pat.max {
				cb.compile_0_or_1(mut c, binding)?
			}
		}
	} else {
		cb.compile_0_or_many(mut c, binding)?
	}
}

fn (mut cb AliasBE) compile_1(mut c Compiler, binding parser.Binding) ? {
	if binding.alias == false {
		idx := c.symbols.find(binding.name) or {
			c.symbols.add(binding.name)
			c.symbols.len() - 1
		}
		c.code.add_open_capture(idx + 1)
	}

	c.compile_elem(binding.pattern, binding.pattern)?

	if binding.alias == false {
		c.code.add_close_capture()
	}
}

fn (mut cb AliasBE) compile_0_or_many(mut c Compiler, binding parser.Binding) ? {
	p1 := c.code.add_choice(0)
	p2 := c.code.len
	cb.compile_1(mut c, binding)?
	c.code.add_partial_commit(p2)
	c.code.update_addr(p1, c.code.len)
}

fn (mut cb AliasBE) compile_1_or_many(mut c Compiler, binding parser.Binding) ? {
	cb.compile_1(mut c, binding)?
	cb.compile_0_or_many(mut c, binding)?
}

fn (mut cb AliasBE) compile_0_or_1(mut c Compiler, binding parser.Binding) ? {
	p1 := c.code.add_choice(0)
	cb.compile_1(mut c, binding)?
	p2 := c.code.add_commit(0)
	c.code.update_addr(p1, c.code.len)
	c.code.update_addr(p2, c.code.len)
	
}
