module vlang

import rosie


struct StringBE {
pub:
	pat rosie.Pattern
	text string
}

fn (cb StringBE) compile(mut c Compiler) ? {
	//eprintln("RPL vlang compiler: StringBE: compile '$cb.text'")
	// TODO escape cb.text
	text := cb.text
	cmd := "m.match_literal('$text')"
	cmd_if := "if match_ == true { match_ = $cmd }\n"

	c.result += "\n"
	if cb.pat.min < 3 {
		for i := 0; i < cb.pat.min; i++ {
			c.result += cmd_if
		}
	} else {
		c.result += "for i := 0; i < $cb.pat.min; i++ {\n    $cmd_if }\n"
	}

	if cb.pat.max == -1 {
		c.result += "for m.pos < m.input.len { if $cmd == false { break } }\n"
	} else if cb.pat.max > cb.pat.min {
		c.result += "for i := $cb.pat.min; (i < $cb.pat.max) && (match_ == true); i++ {\n    $cmd_if }\n"
	}
}
