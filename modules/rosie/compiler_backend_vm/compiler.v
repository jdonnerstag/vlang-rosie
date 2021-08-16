module compiler_backend_vm

import rosie.runtime_v2 as rt
import rosie.parser

struct Compiler {
pub mut:
	parser parser.Parser		// Actually we should only need all the bindings
	symbols rt.Symbols			// capture table
  	code []rt.Slot				// byte code vector
	case_insensitive bool		// Whether current compilation should be case insensitive or not
	pkg_fpath string			// The current package for resolving variable names
	func_implementations map[string]int		// function name => pc: fn entry point
}

pub fn new_compiler(p parser.Parser) Compiler {
	return Compiler{ parser: p, symbols: rt.new_symbol_table(), pkg_fpath: p.package }
}

pub fn (c Compiler) binding(name string) ? &parser.Binding {
	cache := c.parser.package_cache
	return cache.get(c.pkg_fpath)?.get(cache, name)
}

// compile Compile the necessary instructions for a specific
// (public) binding from the rpl file. Use "*" for anonymous
// pattern.
pub fn (mut c Compiler) compile(name string) ? {
	pat := c.parser.pattern(name)?

	c.add_open_capture(name)
	c.compile_elem(pat, pat)?
	c.add_close_capture()
	c.add_end()
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
			pred_p1 = c.add_choice(0)
		}
		.look_ahead {
			// nothing
		}
		.look_behind {
			if behind == 0 { panic("Look-behind is not support for ${typeof(pat).name}")}
			pred_p1 = c.add_choice(0)
			c.add_behind(behind)
		}
		.negative_look_behind {
			if behind == 0 { panic("Look-behind is not support for ${typeof(pat).name}")}
			pred_p1 = c.add_choice(0)
			c.add_behind(behind)
		}
	}
	return pred_p1
}

fn (mut c Compiler) predicate_post(pat parser.Pattern, pred_p1 int) {
	match pat.predicate {
		.na { }
		.negative_look_ahead {
			c.add_fail_twice()
			c.update_addr(pred_p1, c.code.len)
		}
		.look_ahead {
			c.add_reset_pos()
		}
		.look_behind {
			p2 := c.add_jmp(0)
			p3 := c.add_fail()
			c.update_addr(p2, c.code.len)
			c.update_addr(pred_p1, p3)
		}
		.negative_look_behind {
			c.add_fail_twice()
			c.update_addr(pred_p1, c.code.len)
		}
	}
}

pub fn (mut c Compiler) add_open_capture(name string) int {
	idx := c.symbols.find(name) or {
		c.symbols.add(name)
		c.symbols.len() - 1
	}

	rtn := c.code.len
	c.code << rt.opcode_to_slot(.open_capture).set_aux(idx + 1)
	c.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_reset_capture() int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.reset_capture)
	return rtn
}

pub fn (mut c Compiler) add_behind(offset int) int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.behind).set_aux(offset)
	return rtn
}

pub fn (mut c Compiler) add_close_capture() int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.close_capture)
	return rtn
}

pub fn (mut c Compiler) add_end() int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.end)
	return rtn
}

pub fn (mut c Compiler) add_ret() int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.ret)
	return rtn
}

pub fn (mut c Compiler) add_fail() int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.fail)
	return rtn
}

pub fn (mut c Compiler) add_fail_twice() int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.fail_twice)
	return rtn
}

pub fn (mut c Compiler) add_test_any(pos int) int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.test_any)
	c.code << pos - rtn
	return rtn
}

pub fn (mut c Compiler) add_char(ch byte) int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.char).set_char(ch)
	return rtn
}

pub fn (mut c Compiler) add_span(cs rt.Charset) int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.span)
	c.code << cs.data
	return rtn
}

pub fn (mut c Compiler) add_test_char(ch byte, pos int) int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.test_char).set_char(ch)
	c.code << pos - rtn
	return rtn
}

pub fn (mut c Compiler) add_choice(pos int) int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.choice)
	c.code << pos - rtn
	return rtn
}

pub fn (mut c Compiler) add_partial_commit(pos int) int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.partial_commit)
	c.code << pos - rtn
	return rtn
}

pub fn (mut c Compiler) add_any() int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.any)
	return rtn
}

pub fn (mut c Compiler) add_commit(pos int) int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.commit)
	c.code << pos - rtn
	return rtn
}

pub fn (mut c Compiler) add_call(fn_pos int, rtn_pos int, err_pos int, fn_name string) int {
	idx := c.symbols.find(fn_name) or {
		c.symbols.add(fn_name)
		c.symbols.len() - 1
	}

	rtn := c.code.len
	c.code << rt.opcode_to_slot(.call).set_aux(idx + 1)
	c.code << fn_pos - rtn
	c.code << rtn_pos - rtn
	c.code << err_pos - rtn
	return rtn
}

pub fn (mut c Compiler) add_jmp(pos int) int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.jmp)
	c.code << pos - rtn
	return rtn
}

pub fn (mut c Compiler) add_reset_pos() int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.reset_pos)
	return rtn
}

pub fn (mut c Compiler) add_set(cs rt.Charset) int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.set)
	c.code << cs.data
	return rtn
}

pub fn (mut c Compiler) add_test_set(cs rt.Charset, pos int) int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.test_set)
	c.code << pos - rtn
	c.code << cs.data
	return rtn
}

pub fn (mut c Compiler) update_addr(pc int, pos int) {
	c.code[pc + 1] = pos - pc
}
