module compiler_backend_vm

import rosie.runtime as rt
import rosie.parser


struct CharBE {}

fn (mut cb CharBE) compile(mut c Compiler, pat parser.Pattern, ch byte) {
	eprintln(">> ${@FN} len=$c.code.len, code=$c.code")
	defer { eprintln("<< ${@FN} len=$c.code.len, code=$c.code") }

	mut pred_p1 := 0
	if pat.predicate == .negative_look_ahead {
		pred_p1 = c.code.add_choice(0)
	}

	cb.compile_inner(mut c, pat, ch)

	if pat.predicate == .negative_look_ahead {
		c.code.add_fail_twice()
		c.code.update_addr(pred_p1, c.code.len - 2)
	}
}

fn (mut cb CharBE) compile_inner(mut c Compiler, pat parser.Pattern, ch byte) {
	eprintln(">> ${@FN} len=$c.code.len, code=$c.code")
	defer { eprintln("<< ${@FN} len=$c.code.len, code=$c.code") }

	for _ in 0 .. pat.min {
		cb.compile_1(mut c, ch)
	}

	if pat.max != -1 {
		if pat.max > pat.min {
			for _ in pat.min .. pat.max {
				cb.compile_0_or_1(mut c, ch)
			}
		}
	} else {
		cb.compile_0_or_many(mut c, ch)
	}
}

fn (mut cb CharBE) compile_1(mut c Compiler, ch byte) {
	eprintln(">> ${@FN} len=$c.code.len, code=$c.code")
	defer { eprintln("<< ${@FN} len=$c.code.len, code=$c.code") }

	c.code.add_char(ch)
}

fn (mut cb CharBE) compile_0_or_many(mut c Compiler, ch byte) {
	eprintln("${@FN}")
	c.code.add_span(rt.new_charset_with_byte(ch))
}

fn (mut cb CharBE) compile_1_or_many(mut c Compiler, ch byte) {
	eprintln("${@FN}")
	c.code.add_char(ch)
	c.code.add_span(rt.new_charset_with_byte(ch))
}

fn (mut cb CharBE) compile_0_or_1(mut c Compiler, ch byte) {
	eprintln("${@FN}")
	c.code.add_span(rt.new_charset_with_byte(ch))		// TODO The same byte-code for 0..n and 0..1 ?!?!?
}
