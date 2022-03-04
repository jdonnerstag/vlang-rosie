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
	text := cb.text
	cmd := "m.match_literal('$text')"
	str := c.gen_code(cb.pat, cmd)
	return str
}
