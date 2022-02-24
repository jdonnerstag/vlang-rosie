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

	mut str := "\n"
	if cb.pat.min < 3 {
		for i := 0; i < cb.pat.min; i++ {
			str += "match_ = $cmd\n"
			str += "if match_ == false { return false }\n"
		}
	} else {
		str += "for i := 0; i < $cb.pat.min; i++ {\n"
		str += "    match_ = $cmd\n"
		str += "    if match_ == false { return false }\n"
		str += "}\n"
	}

	if cb.pat.max == -1 {
		str += "for m.pos < m.input.len { if $cmd == false { break } }\n"
	} else if cb.pat.max > cb.pat.min {
		diff := cb.pat.max - cb.pat.min
		if diff < 3 {
			for i := cb.pat.min; i < cb.pat.max; i++ {
				if i > cb.pat.min {
					str += "if match_ == true { "
				}
				str += "match_ = $cmd\n"
			}
			str += "}".repeat(diff - 1)
			str += "\nmatch_ = true\n"
		} else {
			str += "for i := $cb.pat.min; i < $cb.pat.max; i++ {\n"
			str += "match_ = $cmd\n"
			str += "if match_ == false { break }\n"
			str += "}\n"
			str += "match_ = true\n"
		}
	}

	return str
}
