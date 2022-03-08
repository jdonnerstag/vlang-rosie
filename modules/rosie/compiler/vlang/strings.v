module vlang

import rosie


struct StringBE {
pub:
	pat rosie.Pattern
	text string
}

fn (cb StringBE) compile(mut c Compiler) ? string {
	//eprintln("RPL vlang compiler: StringBE: compile '$cb.text'")
	// TODO escape cb.text
	fn_name := c.pattern_fn_name()
	mut fn_str := c.open_pattern_fn(fn_name, cb.pat.repr())
	cmd := "m.match_literal('${cb.text}')"
	fn_str += c.gen_code(cb.pat, cmd)
	fn_str += "if match_ == false { m.pos = start_pos } \n"
	fn_str += "return match_ }\n\n"
	c.close_pattern_fn(fn_name, fn_str)

	return "m.${fn_name}()"

}
