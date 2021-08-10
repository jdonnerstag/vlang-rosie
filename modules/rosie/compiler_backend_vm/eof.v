module compiler_backend_vm

import rosie.parser


struct EofBE {}

fn (mut cb EofBE) compile(mut c Compiler, pat parser.Pattern, alias_pat parser.Pattern) ? {
	eof := (alias_pat.elem as parser.EofPattern).eof

	if eof {
		cb.compile_eof(mut c)
	} else {
		cb.compile_bof(mut c)
	}
}

fn (mut cb EofBE) compile_eof(mut c Compiler) {
	p1 := c.code.add_test_any(0)
	c.code.add_fail()
	c.code.update_addr(p1, c.code.len - 2)
}

fn (mut cb EofBE) compile_bof(mut c Compiler) {
	c.code.add_behind(1)
	c.code.add_any()
}
