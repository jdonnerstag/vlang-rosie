module compiler_backend_vm

import rosie.runtime as rt
import rosie.parser

struct Compiler {
pub mut:
	parser parser.Parser		// Actually we should only need all the bindings
	symbols rt.Ktable			// capture table
  	code []rt.Slot				// byte code vector
}

pub fn new_compiler(p parser.Parser) Compiler {
	return Compiler{ parser: p, symbols: rt.new_ktable() }
}

// compile Compile the necessary instructions for a specific
// (public) binding from the rpl file. Use "*" for anonymous
// pattern.
pub fn (mut c Compiler) compile(name string) ? {
	b := c.parser.binding_(name)?
	pat := b.pattern

	c.symbols.add(name)
	c.code.add_open_capture(0)

	if pat.elem is parser.GroupPattern {
		c.compile_group(pat.elem)?
	} else {
		return error("Unable to compile binding '$name' which is of type ${pat.elem.type_name()}")
	}

	c.code.add_close_capture()
	c.code.add_end()
}

pub fn (mut c Compiler) compile_group(group parser.GroupPattern) ? {
	for e in group.ar {
		match e.elem {
			parser.LiteralPattern { c.compile_literal(e)? }
			else {
				return error("Compiler does not yet support AST pattern ${e.elem.type_name()}")
			}
		}
	}
}

pub fn (mut c Compiler) compile_literal(pat parser.Pattern) ? {
	if pat.elem is parser.LiteralPattern {
		text := pat.elem.text
		if text.len == 0 { return }

		for ch in text {
			c.code.add_char(ch)
		}

		if pat.min == 1 && pat.max == -1 {
			if text.len == 1 {
				c.code.add_span(rt.new_charset_with_byte(text[0]))
			} else if text.len > 1 {
				p1 := c.code.add_test_char(text[0], 0)
				p2 := c.code.add_choice(0)
				p3 := c.code.len
				for ch in text {
					c.code.add_char(ch)
				}
				p4 := c.code.add_partial_commit(p3)
				c.code.update_addr(p1, p4)
				c.code.update_addr(p2, p4)
			}
		}
	}
}
