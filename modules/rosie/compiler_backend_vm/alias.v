module compiler_backend_vm

import rosie.parser


struct AliasBE {}

// TODO do we really need to pass 2 pattern ??
fn (cb AliasBE) compile(mut c Compiler, pat parser.Pattern, elem parser.NamePattern) ? {
	name := elem.name

	if c.debug > 49 {
		eprintln("${' '.repeat(c.indent_level)}>> AliasBE: compile(): name='${pat.repr()}', package: '$c.parser.package', len: $c.code.len")
		c.indent_level += 1
		defer {
			c.indent_level -= 1
			eprintln("${' '.repeat(c.indent_level)}<< AliasBE: compile(): name='${pat.repr()}', package: '$c.parser.package', len: $c.code.len")
		}
	}

	mut binding := c.binding(name) or {
		eprintln("name: '$name', package: '$c.parser.package', grammar: '$c.parser.grammar'")
		return error(err.msg)
	}

	if c.debug > 2 { eprintln(binding.repr()) }

	// Resolve variables in the context of the rpl-file (package)
	orig_package := c.parser.package
	c.parser.package = binding.package
	defer { c.parser.package = orig_package }

	orig_grammar := c.parser.grammar
	c.parser.grammar = binding.grammar
	defer { c.parser.grammar = orig_grammar }

	if binding.func || binding.recursive {
		//eprintln("alias: ${binding.repr()}")
		c.compile_func_body(binding)?
	}

	pat_len := c.input_len(binding.pattern) or { 0 }
	pred_p1 := c.predicate_pre(pat, pat_len)?

	cb.compile_inner(mut c, pat, binding)?

	c.predicate_post(pat, pred_p1)
}

fn (cb AliasBE) compile_inner(mut c Compiler, pat parser.Pattern, binding parser.Binding) ? {
	for _ in 0 .. pat.min {
		cb.compile_1(mut c, binding)?
	}

	if pat.max != -1 {
		if pat.max > pat.min {
			cb.compile_0_to_n(mut c, binding, pat.max - pat.min)?
		}
	} else {
		cb.compile_0_to_many(mut c, binding)?
	}
}

fn (cb AliasBE) compile_1(mut c Compiler, binding parser.Binding) ? {
	full_name := binding.full_name()
	if func_pc := c.func_implementations[full_name] {
		// If the function has already been implemented, then just call it.
		p1 := c.add_call(func_pc, 0, 0, full_name)
		p2 := c.add_fail()
		c.update_addr(p1 + 1, c.code.len)
		c.update_addr(p1 + 2, p2)
	} else if binding.alias == false || c.unit_test {
		// 1. Alias means "inline" the byte code.
		// 2. Make sure that aliases can be tested
		c.add_open_capture(full_name)
		c.compile_elem(binding.pattern, binding.pattern)?
		c.add_close_capture()
	} else {
		c.compile_elem(binding.pattern, binding.pattern)?
	}
}

fn (cb AliasBE) compile_0_to_many(mut c Compiler, binding parser.Binding) ? {
	// TODO The current implementation pushes and pops btentries potentially
	// many times. How much more efficient would it be, to avoid it, and just
	// update the btentry and then jump back to the beginning.
	p1 := c.add_choice(0)
	cb.compile_1(mut c, binding)?
	c.add_commit(p1)
	c.update_addr(p1, c.code.len)
}

fn (cb AliasBE) compile_0_to_n(mut c Compiler, binding parser.Binding, max int) ? {
	// TODO Same as above. Is it possible to eliminate btentry push / pops by only
	// updating the btentry
	mut ar := []int{ cap: max }
	for _ in 0 .. max {
		ar << c.add_choice(0)
		cb.compile_1(mut c, binding)?
		p2 := c.add_commit(0)
		c.update_addr(p2, c.code.len)
	}

	for pc in ar { c.update_addr(pc, c.code.len) }
}
