module compiler

import rosie


struct AliasBE {
pub:
	pat rosie.Pattern
	binding rosie.Binding
}


fn (cb AliasBE) compile(mut c Compiler) ? {
	if c.debug > 49 {
		eprintln("${' '.repeat(c.indent_level)}>> AliasBE: compile(): name='${cb.pat.repr()}', package: '$c.parser.current.name', len: $c.rplx.code.len")
		c.indent_level += 1
		defer {
			c.indent_level -= 1
			eprintln("${' '.repeat(c.indent_level)}<< AliasBE: compile(): name='${cb.pat.repr()}', package: '$c.parser.current.name', len: $c.rplx.code.len")
		}
	}

	binding := cb.binding
	if c.debug > 2 { eprintln(binding.repr()) }

	// Set the context used to resolve variable names
	// TODO this is copy & paste from expand(). Can we restructure it some struct?
	orig_current := c.parser.current
	defer { c.parser.current = orig_current }

	if binding.grammar.len > 0 {
		c.parser.current = c.parser.main.package_cache.get(binding.grammar)?
	} else if binding.package.len == 0 || binding.package == "main" {
		c.parser.current = c.parser.main
	} else {
		c.parser.current = c.parser.main.package_cache.get(binding.package)?
	}
	//eprintln("Compiler (AliasBE): name='$binding.name', package='$binding.package', grammar='$binding.grammar', current='$c.parser.current.name', repr=${binding.pattern.repr()}")
	// ------------------------------------------

	if binding.func || binding.recursive {
		//eprintln("alias: ${binding.repr()}")
		c.compile_func_body(binding)?
	}

	mut x := DefaultPatternCompiler{
		pat: cb.pat,
		predicate_be: DefaultPredicateBE{ pat: cb.pat },
		compile_1_be: cb,
		compile_0_to_many_be: DefaultCompile_0_to_many{ pat: cb.pat, compile_1_be: cb }
	}

	x.compile(mut c)?
}

fn (cb AliasBE) compile_1(mut c Compiler) ? {
	binding := cb.binding
	full_name := binding.full_name()
	if func_pc := c.func_implementations[full_name] {
		// If the function has already been implemented, then just call it.
		c.add_call(func_pc, full_name)
	} else if c.unit_test || (c.user_captures.len == 0 && binding.alias == false) || full_name in c.user_captures {
		// 1. Alias means "inline" the byte code.
		// 2. Make sure that aliases can be tested
		c.add_open_capture(full_name)
		c.compile_elem(binding.pattern, binding.pattern)?
		c.add_close_capture()
	} else {
		c.compile_elem(binding.pattern, binding.pattern)?
	}
}
