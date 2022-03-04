module vlang

import rosie


struct MacroBE {
pub:
	pat rosie.Pattern
	elem rosie.MacroPattern
}

fn (cb MacroBE) compile(mut c Compiler) ? string {
	//eprintln("RPL vlang compiler: MacroBE: compile '$cb.text'")
	cmd := cb.get_cmd()?
	str := c.gen_code(cb.pat, cmd)
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
