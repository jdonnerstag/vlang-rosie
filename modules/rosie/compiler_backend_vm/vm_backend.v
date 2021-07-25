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
	return Compiler{ parser: p }
}

// compile Compile the necessary instructions for a specific
// (public) binding from the rpl file. Use "*" for anonymous
// pattern.
pub fn (mut c Compiler) compile(name string) ? {
	b := c.parser.binding_(name)?
	pat := b.pattern
	if pat.elem is parser.GroupPattern {
		return c.compile_group(pat.elem)
	}
	return error("Unable to compile binding '$name' which is of type ${pat.elem.type_name()}")
}

pub fn (mut c Compiler) compile_group(group parser.GroupPattern) ? {
}
