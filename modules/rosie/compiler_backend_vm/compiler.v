module compiler_backend_vm

import rosie.runtime_v2 as rt
import rosie.parser


struct Compiler {
pub:
	unit_test bool				// When compiling for unit tests, the capture ALL variables (incl. alias)

pub mut:
	parser parser.Parser		// Actually we should only need all the bindings
	symbols rt.Symbols			// capture table
  	code []rt.Slot				// byte code vector
	func_implementations map[string]int		// function name => pc: fn entry point
	debug int
	indent_level int
}

pub fn new_compiler(p parser.Parser, unit_test bool, debug int) Compiler {
	return Compiler{
		parser: p,
		symbols: rt.new_symbol_table(),
		debug: debug,
		unit_test: unit_test,
	}
}

[inline]
pub fn (c Compiler) binding(name string) ? &parser.Binding {
	return c.parser.binding(name)
}

pub fn (c Compiler) input_len(pat parser.Pattern) ? int {
	if pat.predicate != .na {
		return 0
	}

	if pat.elem is parser.NamePattern {
		b := c.binding(pat.elem.name)?
		if b.grammar.len > 0 {
			return none	  // Unable to determine input length for recursive pattern
		}
		return c.input_len(b.pattern)
	} else if pat.elem is parser.GroupPattern {
		mut len := 0
		for p in pat.elem.ar {
			len += c.input_len(p) or {
				return err
			}
		}
		return len
	}

	return pat.input_len()
}

// compile Compile the necessary instructions for a specific
// (public) binding from the rpl file. Use "*" for anonymous
// pattern.
pub fn (mut c Compiler) compile(name string) ? {
	b := c.parser.binding(name)?
	if c.debug > 0 { eprintln("Compile: ${b.repr()}") }

	orig_package := c.parser.package
	c.parser.package = b.package
	defer { c.parser.package = orig_package }

	orig_grammar := c.parser.grammar
	c.parser.grammar = b.grammar
	defer { c.parser.grammar = orig_grammar }
/*
	if c.debug > 2 {
		c.add_message("enter: $name")
		defer { c.add_message("matched: $name") }
	}
*/
	if b.recursive == true || b.func == true {
		c.compile_func_body(b)?
	}

	full_name := b.full_name()
	pat := b.pattern
	if func_pc := c.func_implementations[full_name] {
		p1 := c.add_call(func_pc, 0, 0, full_name)
		p2 := c.add_fail()
		c.update_addr(p1 + 1, c.code.len)
		c.update_addr(p1 + 2, p2)
	} else {
		c.add_open_capture(full_name)
		c.compile_elem(pat, pat)?
		c.add_close_capture()
	}
	c.add_end()
}

pub fn (mut c Compiler) compile_func_body(b parser.Binding) ? {
	full_name := b.full_name()
	if full_name in c.func_implementations {
		return
	}

	if b.recursive { c.add_register_recursive(full_name) }

	mut p1 := c.add_jmp(0)
	c.func_implementations[full_name] = c.code.len

	add_capture := b.alias == false || c.unit_test
	if add_capture { c.add_open_capture(full_name) }

	c.compile_elem(b.pattern, b.pattern)?

	if add_capture { c.add_close_capture() }

	c.add_ret()
	c.update_addr(p1, c.code.len)
}

interface TypeBE {
	compile(mut c Compiler, pat parser.Pattern, alias_pat parser.Pattern)?
}

fn (mut c Compiler) compile_elem(pat parser.Pattern, alias_pat parser.Pattern) ? {
	//eprintln("compile_elem: ${pat.repr()}")
	be := match pat.elem {
		parser.LiteralPattern { if pat.elem.text.len == 1 { TypeBE(CharBE{}) } else { TypeBE(StringBE{}) } }
		parser.CharsetPattern { TypeBE(CharsetBE{}) }
		parser.GroupPattern { TypeBE(GroupBE{}) }
		parser.DisjunctionPattern { TypeBE(DisjunctionBE{}) }
		parser.NamePattern { TypeBE(AliasBE{}) }
		parser.EofPattern { TypeBE(EofBE{}) }
		parser.MacroPattern { TypeBE(MacroBE{}) }
		parser.FindPattern { TypeBE(FindBE{}) }
	}

	be.compile(mut c, pat, pat)?
}

fn (mut c Compiler) predicate_pre(pat parser.Pattern, behind int) ? int {
	mut pred_p1 := 0
	match pat.predicate {
		.na { }
		.negative_look_ahead {
			pred_p1 = c.add_choice(0)
		}
		.look_ahead {
			p1 := c.add_partial_commit(0)
			c.update_addr(p1, c.code.len)
		}
		.look_behind {
			if behind == 0 { return error("Look-behind is not supportted for ${pat.elem.type_name()}: ${pat.repr()}") }
			pred_p1 = c.add_choice(0)
			c.add_behind(behind)
		}
		.negative_look_behind {
			if behind == 0 { return error("Negative-Look-behind is not supportted for ${pat.elem.type_name()}: ${pat.repr()}") }
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
			p2 := c.add_commit(0)
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

pub fn (mut c Compiler) add_message(str string) int {
	idx := c.symbols.find(str) or {
		c.symbols.add(str)
		c.symbols.len() - 1
	}

	rtn := c.code.len
	c.code << rt.opcode_to_slot(.message).set_aux(idx + 1)
	return rtn
}

pub fn (mut c Compiler) add_dbg_level(level int) int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.dbg_level).set_aux(level)
	return rtn
}

pub fn (mut c Compiler) add_backref(name string) ? int {
	idx := c.symbols.find(name) or {
		return error("Unable to find back-referenced binding in symbol table: '$name'")
	}

	rtn := c.code.len
	c.code << rt.opcode_to_slot(.backref).set_aux(idx + 1)
	return rtn
}

pub fn (mut c Compiler) add_register_recursive(name string) int {
	idx := c.symbols.find(name) or {
		c.symbols.add(name)
		c.symbols.len() - 1
	}

	rtn := c.code.len
	c.code << rt.opcode_to_slot(.register_recursive).set_aux(idx + 1)
	return rtn
}

pub fn (mut c Compiler) update_addr(pc int, pos int) {
	c.code[pc + 1] = pos - pc
}
