module vlang

import rosie


struct FindBE {
pub:
	pat rosie.Pattern
	elem rosie.FindPattern
}

fn (cb FindBE) compile(mut c Compiler) ? string {
	//eprintln("RPL vlang compiler: FindBE: compile '$cb.text'")
	// TODO
	cmd := "m.match_find()"
	str := c.gen_code(cb.pat, cmd)
	return str
}
