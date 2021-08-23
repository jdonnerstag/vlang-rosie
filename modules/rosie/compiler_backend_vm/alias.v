module compiler_backend_vm

import rosie.parser


struct AliasBE {}

fn (mut cb AliasBE) compile(mut c Compiler, pat parser.Pattern, alias_pat parser.Pattern) ? {
	name := (alias_pat.elem as parser.NamePattern).text

	if c.debug > 49 {
		eprintln("${' '.repeat(c.indent_level)}>> AliasBE: compile(): name='${pat.repr()}', c.package: '$c.package', len: $c.code.len")
		c.indent_level += 1
		defer {
			c.indent_level -= 1
			eprintln("${' '.repeat(c.indent_level)}<< AliasBE: compile(): name='${pat.repr()}', c.package: '$c.package', len: $c.code.len")
		}

		c.add_message("enter: ${pat.repr()}")
		defer { c.add_message("matched: ${pat.repr()}") }
	}

	mut binding := c.binding(name)?
	// eprintln("name: '$name', c.package: '$c.package', binding.package: '$binding.package', binding.grammar: '$binding.grammar'")

	pat_len := c.input_len(binding.pattern) or { 0 }
	pred_p1 := c.predicate_pre(pat, pat_len)

	full_name := binding.full_name()
	if full_name in c.alias_stack {
		// Only in grammars recursions are allowed
		if binding.grammar.len == 0 {
			return error("ERROR: Recursion detected outside a grammar: binding='$full_name'")
		}

		if c.debug > 1 { eprintln("AliasBE: detected recursion: $full_name") }

		binding.func = true
	}

	// Resolve variables in the context of the rpl-file (package)
	package := c.package
	c.alias_stack << full_name
	defer {
		c.package = package
		c.alias_stack.pop()
	}
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
			cb.compile_0_to_n(mut c, binding, pat.max - pat.min)?
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
			c.func_implementations[binding.name] = func_pc
		}
	}

	if has_func == false {
		if binding.alias == false {
			name := binding.full_name()
			c.entry_points[name] = c.code.len
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
	p2 := c.add_commit(0)	// TODO Not sure commit is the right thin to do here
	c.update_addr(p1, c.code.len)
	c.update_addr(p2, c.code.len)
}

fn (mut cb AliasBE) compile_0_to_n(mut c Compiler, binding parser.Binding, max int) ? {
	mut ar := []int{ cap: max }
	for _ in 0 .. max {
		ar << c.add_choice(0)
		cb.compile_1(mut c, binding)?
		p2 := c.add_commit(0)	// TODO Not sure commit is the right thin to do here
		c.update_addr(p2, c.code.len)
	}

	for pc in ar { c.update_addr(pc, c.code.len) }
}
