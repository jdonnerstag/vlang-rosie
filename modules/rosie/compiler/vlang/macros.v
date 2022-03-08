module vlang

import rosie


struct MacroBE {
pub:
	pat rosie.Pattern
	elem rosie.MacroPattern
}

fn (cb MacroBE) compile(mut c Compiler) ? string {
	//eprintln("RPL vlang compiler: MacroBE: compile '$cb.text'")
	fn_name := c.pattern_fn_name()
	mut fn_str := c.open_pattern_fn(fn_name, cb.pat.repr())
	cmd := cb.get_cmd()?
	fn_str += c.gen_code(cb.pat, cmd)
	fn_str += "if match_ == false { m.pos = start_pos } \n"
	fn_str += "return match_ }\n\n"
	c.close_pattern_fn(fn_name, fn_str)

	return "m.${fn_name}()"
}

fn (cb MacroBE) get_cmd() ? string {
	match cb.elem.name {
		"backref" { return "m.match_backref()" }
		"word_boundary" { return "m.match_word_boundary()"  }
		"dot_instr" { return "m.match_dot_instr()" }
		"quote" { return "m.match_quote()" }
		"until" { return "m.match_until()" }
		else {
			return error("The selected compiler backend has no support for macro/function: '$cb.elem.name' => ${cb.pat.repr()}")
		}
	}
}
