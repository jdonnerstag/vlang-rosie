module compiler_vlang

import rosie.parser


struct StringBE {
pub:
	pat parser.Pattern
	text string
}

fn (cb StringBE) compile(mut c Compiler) ? {
	// Optimization: ab optional char
	// TODO apply to charset as well
	if cb.text.len == 1 {
		if cb.pat.min == 0 && cb.pat.max == 1 {
			cb.compile_optional_char(mut c, cb.text[0]) ?
			return
		}
	}

	mut x := DefaultPatternCompiler{
		pat: cb.pat,
		predicate_be: DefaultPredicateBE{ pat: cb.pat }
		compile_1_be: cb,
		compile_0_to_many_be: cb
	}

	x.compile(mut c) ?
}

fn (cb StringBE) compile_1(mut c Compiler) ? {
	if cb.text.len == 2 {
		c.add_char2(cb.text)?
	} else if cb.text.len < 4 {
		for ch in cb.text {
			c.add_char(ch)?
		}
	} else {
		c.add_str(cb.text)?
	}
}

fn (cb StringBE) compile_0_to_many(mut c Compiler) ? {
	c.add_choice(0)?
	cb.compile_1(mut c) ?
	c.add_partial_commit(0)?
}

fn (cb StringBE) compile_optional_char(mut c Compiler, ch byte) ? {
	c.add_test_char(ch, 0)?
	c.add_any()?
}
