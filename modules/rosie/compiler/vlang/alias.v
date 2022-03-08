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

	fn_name := c.pattern_fn_name()
	mut fn_str := c.open_pattern_fn(fn_name, cb.pat.repr())
	cmd := "m." + c.cap_fn_name(alias) + "()"
	fn_str += c.gen_code(cb.pat, cmd)
	fn_str += "if match_ == false { m.pos = start_pos } \n"
	fn_str += "return match_ }\n\n"
	c.close_pattern_fn(fn_name, fn_str)

	// TODO Also need to update and reset c.fn_name and c.fn_idx
	c.current = new_current
	if c.debug > 0 { eprintln("Compile: current='${new_current.name}'; ${alias.repr()}") }
	c.compile_binding(alias)?

	return "m.${fn_name}()"
}
