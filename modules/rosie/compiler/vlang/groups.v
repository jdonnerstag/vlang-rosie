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
	fn_name := "${c.binding_context.fn_name}_group_${c.binding_context.fn_idx}"

	mut str := "\n"
	if cb.pat.min == 1 {
		str += "match_ = m.${fn_name}()\n"
		str += "if match_ == false {\n m.pos = start_pos\n return false }\n"
	} else if cb.pat.min > 0 {
		str += "for i := 0; i < $cb.pat.min; i++ {\n"
		str += "   match_ = m.${fn_name}()\n"
		str += "   if match_ == false {\n m.pos = start_pos\n return false }\n"
		str += "}\n"
	}

	if cb.pat.max == -1 {
		str += "for m.pos < m.input.len {"
		str += "   match_ = m.${fn_name}()\n"
		str += "   if match_ == false { break }\n"
		str += "}\n"
		str += "match_ = true"
	} else if cb.pat.max > cb.pat.min {
		str += "for i := $cb.pat.min; i < $cb.pat.max; i++ {\n"
		str += "   match_ = m.${fn_name}()\n"
		str += "   if match_ == false { break }\n"
		str += "}\n"
		str += "match_ = true"
	}

	mut fn_str := "\nfn (mut m Matcher) ${fn_name}() bool { start_pos := m.pos \n mut match_ := true \n"
	for e in cb.elem.ar {
		fn_str += c.compile_elem(e, e)?
	}
	fn_str += "return true }\n\n"
	c.fragments[fn_name] = fn_str

	return str
}
