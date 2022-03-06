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

	mut last_operator := rosie.OperatorType.sequence
	mut str := "\n"
	for e in cb.elem.ar {
		if last_operator == .sequence {
			str += "match_ = "
		}
		last_operator = e.operator
		str += "("
		str += c.compile_elem(e)?
		if cb.elem.word_boundary {
			str += " && m.match_word_boundary() "
		}
		str += ")"

		if e.operator == .sequence {
			str += "\n if match_ == false { m.pos = start_pos \n return false }\n"
		} else if e.operator == .choice {
			str += " || "
		}
	}

	return str
}
