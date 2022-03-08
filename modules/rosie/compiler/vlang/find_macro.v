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
	fn_name := c.pattern_fn_name()
	mut fn_str := c.open_pattern_fn(fn_name, cb.pat.repr())
	cmd := "m.match_find()"
	fn_str += c.gen_code(cb.pat, cmd)
	fn_str += "if match_ == false { m.pos = start_pos } \n"
	fn_str += "return match_ }\n\n"
	c.close_pattern_fn(fn_name, fn_str)

	return "m.${fn_name}()"
}
