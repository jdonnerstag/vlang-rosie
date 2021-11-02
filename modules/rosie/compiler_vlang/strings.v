module compiler_vlang

import rosie.parser


struct StringBE {
pub:
	pat parser.Pattern
	text string
}

fn (cb StringBE) compile(mut c Compiler) ? {
	if cb.text.len == 1 {
		if cb.pat.min == 1 && cb.pat.max == 1 {
			cb.compile_1(mut c)?
		} else if cb.pat.min == 0 && cb.pat.max == 1 {
			c.out.writeln("if pos < input.len && input[pos] == ${cb.text[0]} {")?
			c.brackets ++
		} else {
			if cb.pat.min > 0 {
				c.out.writeln("pmax := pos + ${cb.pat.min}")?
				c.out.writeln("if pmax < input.len {")?
				c.out.writeln("for ; pos < pmax; pos++ { if input[pos] != ${cb.text[0]} { break } }")?
				c.out.writeln("}")?
				c.out.writeln("if pos == pmax {")?
				c.brackets ++
			}

			if cb.pat.max == -1 {
				c.out.writeln("for pos < input.len && input[pos] == ${cb.text[0]} { pos++ }")?
			} else if cb.pat.max > cb.pat.min {
				c.out.writeln("pmax := pos + ${cb.pat.max} - ${cb.pat.min}")?
				c.out.writeln("for ; pos < pmax; pos++ { if pos >= input.len || input[pos] != ${cb.text[0]} { break } }")?
			}
		}
	}
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
