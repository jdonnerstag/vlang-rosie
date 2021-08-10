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

interface TypeBE {
	compile(mut c Compiler, pat parser.Pattern, alias_pat parser.Pattern)?
}

fn (mut c Compiler) compile_elem(pat parser.Pattern, alias_pat parser.Pattern) ? {
	mut be := match pat.elem {
		parser.LiteralPattern { if pat.elem.text.len == 1 { TypeBE(CharBE{}) } else { TypeBE(StringBE{}) } }
		parser.CharsetPattern { TypeBE(CharsetBE{}) }
		parser.GroupPattern { TypeBE(GroupBE{}) }
		parser.NamePattern { TypeBE(AliasBE{}) }
	}
	be.compile(mut c, pat, pat)?
}
