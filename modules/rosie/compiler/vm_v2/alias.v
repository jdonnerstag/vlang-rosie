module vm_v2

import rosie


struct AliasBE {
mut:
	binding &rosie.Binding = 0
pub:
	pat rosie.Pattern
	name string
}


fn (mut cb AliasBE) compile(mut c Compiler) ? {
	if c.debug > 49 {
		eprintln("${' '.repeat(c.indent_level)}>> AliasBE: compile(): name='${cb.pat.repr()}', package: '$c.current.name', len: $c.rplx.code.len")
		c.indent_level += 1
		defer {
			c.indent_level -= 1
			eprintln("${' '.repeat(c.indent_level)}<< AliasBE: compile(): name='${cb.pat.repr()}', package: '$c.current.name', len: $c.rplx.code.len")
		}
	}
	// Set the context used to resolve variable names
	// TODO this is copy & paste from expand(). Can we restructure it some struct?
	orig_current := c.current
	defer { c.current = orig_current }

	cb.binding, c.current = c.current.get_bp(cb.name)?
	if c.debug > 2 {
		eprintln("Alias: cb.name: $cb.name, current: $c.current.name, ${cb.binding.repr()}")
	}
	// ------------------------------------------

	if cb.binding.func || cb.binding.recursive {
		//eprintln("alias: ${binding.repr()}")
		c.compile_func_body(cb.binding)?
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
	full_name := cb.binding.full_name()
	if func_pc := c.func_implementations[full_name] {
		// If the function has already been implemented, then just call it.
		c.add_call(func_pc, full_name)
	} else if c.unit_test || (c.user_captures.len == 0 && cb.binding.alias == false) || full_name in c.user_captures {
		// 1. Alias means "inline" the byte code.
		// 2. Make sure that aliases can be tested
		c.add_open_capture(full_name)
		c.compile_elem(cb.binding.pattern, cb.binding.pattern)?
		c.add_close_capture()
	} else {
		c.compile_elem(cb.binding.pattern, cb.binding.pattern)?
	}
}
