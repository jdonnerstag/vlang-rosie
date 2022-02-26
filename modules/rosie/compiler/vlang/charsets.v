module vlang

import rosie


enum CharsetBEOptimizations {
	standard
	bit_7
	digits
}

struct CharsetBE {
mut:
	optimization CharsetBEOptimizations = .standard
	count int
pub:
	pat rosie.Pattern
	cs rosie.Charset
}

fn (cb CharsetBE) compile(mut c Compiler) ? string {
	//eprintln("RPL vlang compiler: CharsetBE: compile '$cb.text'")
	id := "cs_${c.constants.len}"
	c.constants << "const ${id} = rosie.to_charset(&${cb.cs.data})\n"
	cmd := "m.match_charset($id)"

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
		str += "match_ = true\n"
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
