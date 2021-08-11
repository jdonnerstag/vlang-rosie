module compiler_backend_vm

import rosie.runtime as rt
import rosie.parser

struct Compiler {
pub mut:
	parser parser.Parser		// Actually we should only need all the bindings
	symbols rt.Ktable			// capture table
  	code []rt.Slot				// byte code vector
	case_insensitive bool		// Whether current compilation should be case insensitive or not
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
	// TODO "be" doesn't need to be mutable ?!?!
	mut be := match pat.elem {
		parser.LiteralPattern { if pat.elem.text.len == 1 { TypeBE(CharBE{}) } else { TypeBE(StringBE{}) } }
		parser.CharsetPattern { TypeBE(CharsetBE{}) }
		parser.GroupPattern { TypeBE(GroupBE{}) }
		parser.NamePattern { TypeBE(AliasBE{}) }
		parser.EofPattern { TypeBE(EofBE{}) }
		parser.MacroPattern { TypeBE(MacroBE{}) }
	}

	be.compile(mut c, pat, pat)?
}

fn (mut c Compiler) predicate_pre(pat parser.Pattern, behind int) int {
	mut pred_p1 := 0
	match pat.predicate {
		.na { }
		.negative_look_ahead {
			pred_p1 = c.code.add_choice(0)
		}
		.look_ahead {
			// nothing
		}
		.look_behind {
			if behind == 0 { panic("Look-behind is not support for ${typeof(pat).name}")}
			pred_p1 = c.code.add_choice(0)
			c.code.add_behind(behind)
		}
		.negative_look_behind {
			if behind == 0 { panic("Look-behind is not support for ${typeof(pat).name}")}
			pred_p1 = c.code.add_choice(0)
			c.code.add_behind(behind)
		}
	}
	return pred_p1
}

fn (mut c Compiler) predicate_post(pat parser.Pattern, pred_p1 int) {
	match pat.predicate {
		.na { }
		.negative_look_ahead {
			c.code.add_fail_twice()
			c.code.update_addr(pred_p1, c.code.len - 2)
		}
		.look_ahead {
			c.code.add_reset_pos()
		}
		.look_behind {
			p2 := c.code.add_jmp(0)
			p3 := c.code.add_fail()
			c.code.update_addr(p2, c.code.len - 2)
			c.code.update_addr(pred_p1, p3 - 2)
		}
		.negative_look_behind {
			c.code.add_fail_twice()
			c.code.update_addr(pred_p1, c.code.len - 2)
		}
	}
}
