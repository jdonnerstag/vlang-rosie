module vlang

import rosie


struct EofBE {
pub:
	pat rosie.Pattern
	eof bool
}

fn (cb EofBE) compile(mut c Compiler) ? string {
	//eprintln("RPL vlang compiler: EofBE: compile '$cb.eof'")
	mut str := "\n"
	if cb.eof == false {
		str += "if m.pos > 0 { return false }\n"
	} else {
		str += "if m.pos >= m.input.len { return false }\n"
	}
	return str
}
