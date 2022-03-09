module vlang

import rosie


struct EofBE {
pub:
	pat rosie.Pattern
	eof bool
}

fn (cb EofBE) compile(mut c Compiler) ? string {
	//eprintln("RPL vlang compiler: EofBE: compile '$cb.eof'")
	if cb.eof == false {
		return "m.pos == 0"
	} else {
		return "m.pos >= m.input.len"
	}
}
