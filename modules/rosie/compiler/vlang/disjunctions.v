module vlang

import rosie


struct DisjunctionBE {
pub:
	pat rosie.Pattern
	elem rosie.DisjunctionPattern
}

fn (cb DisjunctionBE) compile(mut c Compiler) ? string {
eprintln("RPL vlang compiler: DisjunctionBE: compile '${cb.pat.repr()}; elem: ${cb.elem.repr()}; negated: $cb.elem.negative")
	orig_pattern_context := c.pattern_context
	c.pattern_context = CompilerPatternContext{ is_sequence: false, negate: cb.elem.negative }
	defer { c.pattern_context = orig_pattern_context }

	c.binding_context.fn_idx ++
	fn_name := c.pattern_fn_name()
	c.fragments[fn_name] = ""
	mut fn_str := "\n"
	fn_str += "// Pattern: ${cb.pat.repr()} \n"
	fn_str += "fn (mut m Matcher) ${fn_name}() bool { start_pos := m.pos \n mut match_ := true \n"
	for e in cb.elem.ar {
		fn_str += "match_ = " + c.compile_elem(e)?
		if cb.elem.negative == false {
			fn_str += " \n if match_ == true { return true } \n "
		} else {
			fn_str += " \n if match_ == true { m.pos = start_pos \n return false} \n "
		}
	}
	if cb.elem.negative == false {
		fn_str += "m.pos = start_pos \n"
		fn_str += "return false \n } \n"
	} else {
		fn_str += "if m.pos < m.input.len { m.pos ++ } \n"
		fn_str += "return true \n } \n"
	}
	c.fragments[fn_name] = fn_str

	cmd := "m.${fn_name}()"
	str := c.gen_code(cb.pat, cmd)

/*
	if c.pattern_context.negate == false {
		str += "return false \n"
	} else {
		str += "if m.pos < m.input.len { m.pos ++ } \n"
		str += "return true \n"
	}
*/
	return str
}
