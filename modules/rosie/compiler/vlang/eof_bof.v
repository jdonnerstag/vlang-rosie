module vlang

import rosie


struct EofBE {
pub:
	pat rosie.Pattern
	eof bool
}

fn (cb EofBE) compile(mut c Compiler) ? string {
	//eprintln("RPL vlang compiler: EofBE: compile '$cb.eof'")
	fn_name_outer := c.pattern_fn_name()
	mut fn_str := c.open_pattern_fn(fn_name_outer, cb.pat.repr())

	fn_name_inner := cb.gen_inner_code(mut c)?
	cmd := "m.${fn_name_inner}()"
	fn_str += c.gen_code(cb.pat, cmd)
	fn_str += "if match_ == false { m.pos = start_pos } \n"
	fn_str += "return match_ }\n\n"
	c.close_pattern_fn(fn_name_outer, fn_str)

	return "m.${fn_name_outer}()"
}

fn (cb EofBE) gen_inner_code(mut c Compiler) ? string {
	fn_name := c.pattern_fn_name()
	mut fn_str := c.open_pattern_fn(fn_name, cb.pat.repr())

	if cb.eof == false {
		fn_str += "return m.pos == 0 \n"
	} else {
		fn_str += "return m.pos >= m.input.len \n"
	}

	fn_str += "} \n"
	c.close_pattern_fn(fn_name, fn_str)
	return fn_name
}
