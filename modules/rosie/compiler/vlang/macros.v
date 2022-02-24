module vlang

import rosie


struct MacroBE {
pub:
	pat rosie.Pattern
	elem rosie.MacroPattern
}

fn (cb MacroBE) compile(mut c Compiler) ? string {
	//eprintln("RPL vlang compiler: MacroBE: compile '$cb.text'")
	mut str := "\n"
	mut end_str := ""
	if cb.pat.min == 1 {
		str += "{\n"
		end_str = "\nif match_ == false { return false } }\n"
	} else if cb.pat.min > 0 {
		str += "for i := 0; i < $cb.pat.min; i++ {\n"
		end_str = "\nif match_ == false { return false } }\n"
	}

	if cb.pat.max == -1 {
		str += "for m.pos < m.input.len {"
		end_str = "\nif match_ == false { break } }\n"
		end_str += "match_ = true\n"
	} else if cb.pat.max > cb.pat.min {
		str += "for i := $cb.pat.min; i < $cb.pat.max; i++ {\n"
		end_str = "if match_ == false { break } }\n"
		end_str += "match_ = true\n"
	}

	cmd := cb.get_cmd()?
	str += "match_ = ${cmd}\n"
	str += end_str
	return str
}

fn (cb MacroBE) get_cmd() ? string {
	match cb.elem.name {
		"backref" { return "m.match_backref()" }
		"word_boundary" { return "m.match_word_boudary()"  }
		"dot_instr" { return "m.match_dot_instr()" }
		"quote" { return "m.match_quote()" }
		"until" { return "m.match_until()" }
		else {
			return error("The selected compiler backend has no support for macro/function: '$cb.elem.name' => ${cb.pat.repr()}")
		}
	}
}
