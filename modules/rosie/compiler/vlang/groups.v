module vlang

import rosie


struct GroupBE {
pub:
	pat rosie.Pattern
	elem rosie.GroupPattern
}

fn (cb GroupBE) compile(mut c Compiler) ? string {
	//eprintln("RPL vlang compiler: GroupBE: compile '$cb.text'")
	orig_pattern_context := c.pattern_context
	c.pattern_context = CompilerPatternContext{ is_sequence: true, negate: false }
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

fn (cb GroupBE) gen_elem_code(mut c Compiler) ? string {
	fn_name := c.pattern_fn_name()
	mut fn_str := c.open_pattern_fn(fn_name, cb.pat.repr())

	mut last_operator := rosie.OperatorType.sequence
	for e in cb.elem.ar {
		if last_operator == .sequence {
			fn_str += "match_ = "
		}
		last_operator = e.operator
		fn_str += "("
		fn_str += c.compile_elem(e)?
		if cb.elem.word_boundary {
			fn_str += " && m.match_word_boundary() "
		}
		fn_str += ")"

		if e.operator == .sequence {
			fn_str += "\n if match_ == false { m.pos = start_pos \n return false }\n"
		} else if e.operator == .choice {
			fn_str += " || "
		}
	}

	fn_str += "return true \n } \n"
	c.close_pattern_fn(fn_name, fn_str)
	return fn_name
}
