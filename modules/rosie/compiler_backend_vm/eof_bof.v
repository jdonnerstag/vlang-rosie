module compiler_backend_vm

import rosie.parser


struct EofBE {
pub:
	pat parser.Pattern
	eof bool
}

fn (cb EofBE) compile(mut c Compiler) ? {
	if cb.eof {
		cb.compile_eof(mut c)
	} else {
		cb.compile_bof(mut c)
	}
}

fn (cb EofBE) compile_eof(mut c Compiler) {
	// TODO Even though it is not cumbersome, an eof byte code instruction
	// would be more readable
	p1 := c.add_test_any(0)
	c.add_fail()
	c.update_addr(p1, c.code.len)
}

fn (cb EofBE) compile_bof(mut c Compiler) {
	// TODO Same for bof. A trivial byte code instruction makes it more readable
	p1 := c.add_choice(0)
	c.add_behind(1)
	c.add_fail_twice()
	c.update_addr(p1, c.code.len)
}
