module vlang

import rosie


struct AliasBE {
pub:
	pat rosie.Pattern
	name string
}

// TODO PLease see StringBE for some improvements

fn (cb AliasBE) compile(mut c Compiler) ? string {
	//eprintln("RPL vlang compiler: AliasBE: compile '$cb.name'")
	alias, new_current := c.current.get_bp(cb.name)?
	cmd := "m." + "cap_${alias.full_name()}()".replace(".", "_")

	mut str := "\n"
	if cb.pat.min < 3 {
		for i := 0; i < cb.pat.min; i++ {
			str += "match_ = $cmd\n"
			str += "if match_ == false { return false }\n"
		}
	} else {
		str += "for i := 0; i < $cb.pat.min; i++ {\n"
		str += "match_ = $cmd\n"
		str += "if match_ == false { return false } }\n"
	}

	if cb.pat.max == -1 {
		str += "for m.pos < m.input.len { if $cmd == false { break } }\n"
		str += "match_ = true\n"
	} else if cb.pat.max > cb.pat.min {
		str += "for i := $cb.pat.min; (i < $cb.pat.max) && (match_ == true); i++ {\n"
		str += "match_ = $cmd\n"
		str += "}\n"
		str += "match_ = true\n"
	}

	// TODO Also need to update and reset c.fn_name and c.fn_idx
	c.current = new_current
	if c.debug > 0 { eprintln("Compile: current='${new_current.name}'; ${alias.repr()}") }
	c.compile_binding(alias, false)?

	return str
}
