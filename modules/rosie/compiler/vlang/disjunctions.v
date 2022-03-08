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

	fn_name_outer := c.pattern_fn_name()
	mut fn_str := c.open_pattern_fn(fn_name_outer, cb.pat.repr())

	fn_name_inner := cb.gen_elem_code(mut c)?
	cmd := "m.${fn_name_inner}()"
	fn_str += c.gen_code(cb.pat, cmd)
	fn_str += "if match_ == false { m.pos = start_pos } \n"
	fn_str += "return match_ \n } \n"
	c.close_pattern_fn(fn_name_outer, fn_str)

	return "m.${fn_name_outer}()"
}

fn (cb DisjunctionBE) gen_elem_code(mut c Compiler) ? string {
	fn_name := c.pattern_fn_name()
	mut fn_str := c.open_pattern_fn(fn_name, cb.pat.repr())

	if cb.elem.negative == false {
		for e in cb.elem.ar {
			fn_str += "match_ = ${c.compile_elem(e)?} \n"
			fn_str += "if match_ == true { return true } \n "
		}
		fn_str += "m.pos = start_pos \n"
		fn_str += "return false \n } \n"
	} else {
		for e in cb.elem.ar {
			fn_str += "match_ = ${c.compile_elem(e)?} \n"
			fn_str += "if match_ == true { m.pos = start_pos \n return false } \n "
		}
		fn_str += "if m.pos < m.input.len { m.pos ++ } \n"
		fn_str += "return true \n } \n"
	}
	c.close_pattern_fn(fn_name, fn_str)
	return fn_name
}
