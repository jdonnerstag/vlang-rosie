module vlang

import rosie


struct DisjunctionBE {
pub:
	pat rosie.Pattern
	elem rosie.DisjunctionPattern
}

fn (cb DisjunctionBE) compile(mut c Compiler) ? string {
eprintln("RPL vlang compiler: DisjunctionBE: compile '${cb.pat.repr()}; elem: ${cb.elem.repr()}; negated: $cb.elem.negative")
	c.binding_context.fn_idx ++
	fn_name := "cap_${c.current.name}_${c.binding_context.fn_name}_group_${c.binding_context.fn_idx}"

	cmd := "m.${fn_name}()"
	str := c.gen_code(cb.pat, cmd)

	orig_pattern_context := c.pattern_context
	c.pattern_context = CompilerPatternContext{ is_sequence: false, negate: cb.elem.negative }
	defer { c.pattern_context = orig_pattern_context }

	mut fn_str := "\nfn (mut m Matcher) ${fn_name}() bool { start_pos := m.pos \n mut match_ := true \n"
	for e in cb.elem.ar {
		fn_str += c.compile_elem(e)?
	}
	if c.pattern_context.negate == false {
		fn_str += "return false \n"
	} else {
		fn_str += "if m.pos < m.input.len { m.pos ++ } \n"
		fn_str += "return true \n"
	}
	fn_str += "}\n\n"
	c.fragments[fn_name] = fn_str

	return str
}
