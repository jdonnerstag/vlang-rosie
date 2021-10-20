module compiler_backend_vm

import rosie.runtime_v2 as rt
import rosie.parser


struct Compiler {
pub:
	unit_test bool				// When compiling for unit tests, then capture ALL variables (incl. alias)

pub mut:
	parser parser.Parser		// Actually we should only need all the bindings
	symbols rt.Symbols			// capture table
  	code []rt.Slot				// byte code vector
	func_implementations map[string]int		// function name => pc: fn entry point
	debug int
	indent_level int
	user_captures []string		// User may override which variables are captured. (back-refs are always captured)
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
	if pat.elem is parser.NamePattern {
		b := c.binding(pat.elem.name)?
		if b.grammar.len > 0 {
			return none	  // Unable to determine input length for recursive pattern
		}
		return c.input_len(b.pattern)
	} else if pat.elem is parser.GroupPattern {
		// TODO: GroupPattern has an input_len() method, but it is not able to resolve NamePattern.
		mut len := 0
		for p in pat.elem.ar {
			if p.predicate != .na {
				len += c.input_len(p) or {
					return err
				}
			}
		}
		return len
	}

	// Ignore the predicate of the outer most pattern, because it is the input-len
	// of this pattern, that we want to determine.
	return pat.elem.input_len()
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

	if b.recursive == true || b.func == true {
		c.compile_func_body(b)?
	}

	full_name := b.full_name()
	pat := b.pattern
	if func_pc := c.func_implementations[full_name] {
		c.add_call(func_pc, full_name)
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

	p2 := c.add_choice(0)

	c.compile_elem(b.pattern, b.pattern)?

	if add_capture { c.add_close_capture() }

	c.add_ret()
	c.update_addr(p2, c.code.len)
	c.add_fail_twice()
	c.update_addr(p1, c.code.len)
}

fn (mut c Compiler) compile_elem(pat parser.Pattern, alias_pat parser.Pattern) ? {
	//eprintln("compile_elem: ${pat.repr()}")
	mut be := match pat.elem {
		parser.LiteralPattern { PatternCompiler(StringBE{ pat: pat, text: pat.elem.text }) }
		parser.CharsetPattern { PatternCompiler(CharsetBE{ pat: pat, cs: pat.elem.cs }) }
		parser.GroupPattern { PatternCompiler(GroupBE{ pat: pat, elem: pat.elem }) }
		parser.DisjunctionPattern { PatternCompiler(DisjunctionBE{ pat: pat, elem: pat.elem }) }
		parser.NamePattern {
			b := c.binding(pat.elem.name)?
			PatternCompiler(AliasBE{ pat: pat, binding: b })
		}
		parser.EofPattern { PatternCompiler(EofBE{ pat: pat, eof: pat.elem.eof }) }
		parser.MacroPattern { PatternCompiler(MacroBE{ pat: pat, elem: pat.elem }) }
		parser.FindPattern { PatternCompiler(FindBE{ pat: pat, elem: pat.elem }) }
	}

	be.compile(mut c)?
}

pub fn (mut c Compiler) add_open_capture(name string) int {
	idx := c.symbols.add(name)
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.open_capture).set_aux(idx)
	c.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_behind(offset int) int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.behind).set_aux(offset)
	c.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_close_capture() int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.close_capture)
	c.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_end() int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.end)
	c.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_ret() int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.ret)
	c.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_fail() int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.fail)
	c.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_fail_twice() int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.fail_twice)
	c.code << rt.Slot(0)
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
	c.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_until_char(ch byte) int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.until_char).set_char(ch)
	c.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_span(cs rt.Charset) int {
	idx := c.symbols.add(cs)

	rtn := c.code.len
	c.code << rt.opcode_to_slot(.span).set_aux(idx)
	c.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_test_char(ch byte, pos int) int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.test_char).set_char(ch)
	c.code << pos - rtn
	return rtn
}

pub fn (mut c Compiler) add_if_char(ch byte, pos int) int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.if_char).set_char(ch)
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

pub fn (mut c Compiler) add_back_commit(pos int) int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.back_commit)
	c.code << pos - rtn
	return rtn
}

pub fn (mut c Compiler) add_any() int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.any)
	c.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_commit(pos int) int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.commit)
	c.code << pos - rtn
	return rtn
}

pub fn (mut c Compiler) add_call(fn_pos int, fn_name string) int {
	idx := c.symbols.add(fn_name)

	rtn := c.code.len
	c.code << rt.opcode_to_slot(.call).set_aux(idx)
	c.code << fn_pos - rtn
	return rtn
}

pub fn (mut c Compiler) add_jmp(pos int) int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.jmp)
	c.code << pos - rtn
	return rtn
}

pub fn (mut c Compiler) add_set(cs rt.Charset) int {
	idx := c.symbols.add(cs)

	rtn := c.code.len
	c.code << rt.opcode_to_slot(.set).set_aux(idx)
	c.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_set_from_to(from int, to int) int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.set_from_to).set_aux((from & 0xff) | ((to << 8) & 0xff_00))
	c.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_until_set(cs rt.Charset) int {
	idx := c.symbols.add(cs)

	rtn := c.code.len
	c.code << rt.opcode_to_slot(.until_set).set_aux(idx)
	c.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_test_set(cs rt.Charset, pos int) int {
	idx := c.symbols.add(cs)

	rtn := c.code.len
	c.code << rt.opcode_to_slot(.test_set).set_aux(idx)
	c.code << pos - rtn
	return rtn
}

pub fn (mut c Compiler) add_if_str(str string, pos int) int {
	idx := c.symbols.add(str)

	rtn := c.code.len
	c.code << rt.opcode_to_slot(.if_str).set_aux(idx)
	c.code << pos - rtn
	return rtn
}

pub fn (mut c Compiler) add_str(str string) int {
	idx := c.symbols.add(str)

	rtn := c.code.len
	c.code << rt.opcode_to_slot(.str).set_aux(idx)
	c.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_message(str string) int {
	idx := c.symbols.add(str)
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.message).set_aux(idx)
	c.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_backref(name string) ? int {
	idx := c.symbols.find(name) or {
		return error("Unable to find back-referenced binding in symbol table: '$name'")
	}

	rtn := c.code.len
	c.code << rt.opcode_to_slot(.backref).set_aux(idx)
	c.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_register_recursive(name string) int {
	idx := c.symbols.add(name)
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.register_recursive).set_aux(idx)
	c.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_word_boundary() int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.word_boundary)
	c.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_dot_instr() int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.dot)
	c.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_bit_7() int {
	rtn := c.code.len
	c.code << rt.opcode_to_slot(.bit_7)
	c.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) update_addr(pc int, pos int) {
	c.code[pc + 1] = pos - pc
}
