module compiler_backend_vm

import rosie.parser


struct AliasBE {}

fn (mut cb AliasBE) compile(mut c Compiler, pat parser.Pattern, alias_pat parser.Pattern) ? {
	// eprintln(">> AliasBE: compile(): pat='$alias_pat.repr()'")
	// defer { eprintln("<< AliasBE: compile(): pat='$alias_pat.repr()'") }

	name := (alias_pat.elem as parser.NamePattern).text

	pred_p1 := c.predicate_pre(pat, 0)	// look-behind is not supported with aliases
	// TODO But it could. It rather depends on the pattern (fixed known length)

	binding := c.binding(name)?
	eprintln("name: '$name', c.package: '$c.package', binding.package: '$binding.package', binding.grammar: '$binding.grammar'")

	// Resolve variables in the context of the rpl-file (package)
	package := c.package
	defer {	c.package = package }
	c.package = if binding.grammar.len > 0 { binding.grammar } else { binding.package }

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
	has_func := binding.name in c.func_implementations
	mut func_pc := 0
	mut p1 := 0
	if binding.func == true {
		if has_func {
			func_pc = c.func_implementations[binding.name]
		} else {
			p1 = c.add_jmp(0)
			func_pc = c.code.len
		}
	}

	if has_func == false {
		if binding.alias == false {
			name := binding.full_name()
			//eprintln("alias: name: $name")
			c.add_open_capture(name)
		}

		c.compile_elem(binding.pattern, binding.pattern)?

		if binding.alias == false {
			c.add_close_capture()
		}

		if p1 > 0 {
			c.add_ret()
			c.update_addr(p1, c.code.len)
			c.func_implementations[binding.name] = func_pc
		}
	}

	if func_pc > 0 {
		p1 = c.add_call(func_pc, 0, 0, binding.name)
		p2 := c.add_fail()
		c.update_addr(p1 + 1, c.code.len)
		c.update_addr(p1 + 2, p2)
	}
}

fn (mut cb AliasBE) compile_0_or_many(mut c Compiler, binding parser.Binding) ? {
	p1 := c.add_choice(0)
	p2 := c.code.len
	cb.compile_1(mut c, binding)?
	c.add_partial_commit(p2)
	c.update_addr(p1, c.code.len)
}

fn (mut cb AliasBE) compile_1_or_many(mut c Compiler, binding parser.Binding) ? {
	cb.compile_1(mut c, binding)?
	cb.compile_0_or_many(mut c, binding)?
}

fn (mut cb AliasBE) compile_0_or_1(mut c Compiler, binding parser.Binding) ? {
	p1 := c.add_choice(0)
	cb.compile_1(mut c, binding)?
	p2 := c.add_commit(0)
	c.update_addr(p1, c.code.len)
	c.update_addr(p2, c.code.len)
}
