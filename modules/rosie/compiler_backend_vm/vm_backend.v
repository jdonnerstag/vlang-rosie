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

	c.symbols.add(name)
	c.code.add_open_capture(c.symbols.len())
	c.compile_elem(b.pattern, b.pattern)?
	c.code.add_close_capture()
	c.code.add_end()
}

fn (mut c Compiler) compile_elem(pat parser.Pattern, alias_pat parser.Pattern) ? {
	match pat.elem {
		parser.LiteralPattern {
			if pat.elem.text.len == 1 {
				mut be := CharBE{}
				be.compile(mut c, pat, pat.elem.text[0])
			} else {
				mut be := StringBE{}
				be.compile(mut c, pat, pat.elem.text)
			}
		} parser.CharsetPattern {
			mut be := CharsetBE{}
			be.compile(mut c, pat, pat.elem.cs)
		} parser.GroupPattern {
			mut be := GroupBE{}
			be.compile(mut c, pat, pat.elem)?
		} parser.NamePattern {
			mut be := AliasBE{}
			be.compile(mut c, pat, pat.elem.text)?
		} parser.AnyPattern {
			mut be := AliasBE{}
			be.compile(mut c, pat, ".")?
		}
	}
}
