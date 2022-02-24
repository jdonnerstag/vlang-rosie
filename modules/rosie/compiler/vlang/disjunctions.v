module vlang

import rosie


struct DisjunctionBE {
pub:
	pat rosie.Pattern
	elem rosie.DisjunctionPattern
}

fn (cb DisjunctionBE) compile(mut c Compiler) ? string {
	//eprintln("RPL vlang compiler: DisjunctionBE: compile '$cb.text'")
	mut str := "\n"
	mut end_str := ""
	if cb.pat.min == 1 {
		str += "{\n"
		end_str = "\nif match_ == false { return false } }\n"
	} else if cb.pat.min > 0 {
		str += "for i := 0; i < $cb.pat.min; i++ {\n"
		end_str = "\nif match_ == false { return false } }\n"
	}

	if cb.pat.max == -1 {
		str += "for m.pos < m.input.len {"
		end_str = "\nif match_ == false { break } }\n"
		end_str += "match_ = true\n"
	} else if cb.pat.max > cb.pat.min {
		str += "for i := $cb.pat.min; i < $cb.pat.max; i++ {\n"
		end_str = "if match_ == false { break } }\n"
		end_str += "match_ = true\n"
	}

	for e in cb.elem.ar {
		str += c.compile_elem(e, e)?
		str += "if match_ == true { continue }\n"
	}
	str += "if match_ == false { return false }\n"

	str += end_str
	return str
}
