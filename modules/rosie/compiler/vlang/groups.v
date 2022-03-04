module vlang

import rosie


struct GroupBE {
pub:
	pat rosie.Pattern
	elem rosie.GroupPattern
}

fn (cb GroupBE) compile(mut c Compiler) ? string {
	//eprintln("RPL vlang compiler: GroupBE: compile '$cb.text'")
	c.binding_context.fn_idx ++
	fn_name := "cap_${c.current.name}_${c.binding_context.fn_name}_group_${c.binding_context.fn_idx}"
	cmd := "m.${fn_name}()"
	str := c.gen_code(cb.pat, cmd)

	orig_pattern_context := c.pattern_context
	c.pattern_context = CompilerPatternContext{ is_sequence: true, negate: false }
	defer { c.pattern_context = orig_pattern_context }

	mut fn_str := "\nfn (mut m Matcher) ${fn_name}() bool { start_pos := m.pos \n mut match_ := true \n"
	for e in cb.elem.ar {
		fn_str += c.compile_elem(e)?
	}
	fn_str += "return true }\n\n"
	c.fragments[fn_name] = fn_str

	return str
}
