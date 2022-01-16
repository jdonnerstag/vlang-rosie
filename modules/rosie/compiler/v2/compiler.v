module v2

import rosie
import rosie.runtimes.v2 as rt

struct Compiler {
pub:
	unit_test bool				// When compiling for unit tests, then capture ALL variables (incl. alias)

pub mut:
	current &rosie.Package		// The current package context: either "main" or a grammar package
	rplx &rt.Rplx				// symbols, charsets, instructions
	func_implementations map[string]int		// function name => pc: fn entry point
	debug int
	indent_level int
	user_captures []string		// User may override which variables are captured. (back-refs are always captured)
}

[params]
pub struct FnNewCompilerOptions {
	rplx &rt.Rplx = &rt.Rplx{}
	user_captures []string
	unit_test bool
	debug int
	indent_level int = 2
}

pub fn new_compiler(main &rosie.Package, args FnNewCompilerOptions) Compiler {
	return Compiler{
		current: main
		rplx: args.rplx
		debug: args.debug
		indent_level: args.indent_level
		unit_test: args.unit_test
		user_captures: args.user_captures
	}
}

[inline]
pub fn (c Compiler) binding(name string) ? &rosie.Binding {
	return c.current.get(name)
}

pub fn (c Compiler) input_len(pat rosie.Pattern) ? int {
	if pat.elem is rosie.NamePattern {
		b := c.binding(pat.elem.name)?
		if b.grammar.len > 0 {
			return none	  // Unable to determine input length for recursive pattern
		}
		return c.input_len(b.pattern)
	} else if pat.elem is rosie.GroupPattern {
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
	if c.debug > 0 { eprintln("Compile pattern for binding: '$name'") }
	b := c.binding(name)?
	if c.debug > 0 { eprintln("Compile: ${b.repr()}") }

	// Set the context used to resolve variable names
	orig_current := c.current
	defer { c.current = orig_current }

eprintln("111: name: $name, ${b.repr()}")
	c.current = c.current.get_relevant_pkg(name)?.context(b)?
	//eprintln("Compiler: name='$name', package='$b.package', grammar='$b.grammar', current='$c.current.name', repr=${b.pattern.repr()}")
	// ------------------------------------------

	if b.recursive == true || b.func == true {
		c.compile_func_body(b)?
	}

	full_name := b.full_name()
	c.rplx.entrypoints.add(name: full_name, start_pc: c.rplx.code.len)?

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

pub fn (mut c Compiler) compile_func_body(b rosie.Binding) ? {
	full_name := b.full_name()
	if full_name in c.func_implementations {
		return
	}

	if b.recursive { c.add_register_recursive(full_name) }

	mut p1 := c.add_jmp(0)
	c.func_implementations[full_name] = c.rplx.code.len

	add_capture := b.alias == false || c.unit_test
	if add_capture { c.add_open_capture(full_name) }

	p2 := c.add_choice(0)

	c.compile_elem(b.pattern, b.pattern)?

	if add_capture { c.add_close_capture() }

	c.add_ret()
	c.update_addr(p2, c.rplx.code.len)
	c.add_fail_twice()
	c.update_addr(p1, c.rplx.code.len)
}

fn (mut c Compiler) compile_elem(pat rosie.Pattern, alias_pat rosie.Pattern) ? {
	//eprintln("compile_elem: ${pat.repr()}")
	mut be := match pat.elem {
		rosie.LiteralPattern { PatternCompiler(StringBE{ pat: pat, text: pat.elem.text }) }
		rosie.CharsetPattern { PatternCompiler(CharsetBE{ pat: pat, cs: pat.elem.cs }) }
		rosie.GroupPattern { PatternCompiler(GroupBE{ pat: pat, elem: pat.elem }) }
		rosie.DisjunctionPattern { PatternCompiler(DisjunctionBE{ pat: pat, elem: pat.elem }) }
		rosie.NamePattern {
			b := c.binding(pat.elem.name)?
			PatternCompiler(AliasBE{ pat: pat, binding: b, name: pat.elem.name })
		}
		rosie.EofPattern { PatternCompiler(EofBE{ pat: pat, eof: pat.elem.eof }) }
		rosie.MacroPattern { PatternCompiler(MacroBE{ pat: pat, elem: pat.elem }) }
		rosie.FindPattern { PatternCompiler(FindBE{ pat: pat, elem: pat.elem }) }
	}

	be.compile(mut c)?
}

pub fn (mut c Compiler) add_open_capture(name string) int {
	idx := c.rplx.symbols.add(name)
	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.open_capture).set_aux(idx)
	c.rplx.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_behind(offset int) int {
	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.behind).set_aux(offset)
	c.rplx.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_close_capture() int {
	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.close_capture)
	c.rplx.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_end() int {
	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.end)
	c.rplx.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_digit() int {
	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.digit)
	c.rplx.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_ret() int {
	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.ret)
	c.rplx.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_fail() int {
	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.fail)
	c.rplx.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_fail_twice() int {
	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.fail_twice)
	c.rplx.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_test_any(pos int) int {
	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.test_any)
	c.rplx.code << pos - rtn
	return rtn
}

pub fn (mut c Compiler) add_char(ch byte) int {
	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.char).set_char(ch)
	c.rplx.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_until_char(ch byte) int {
	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.until_char).set_char(ch)
	c.rplx.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_span(cs rosie.Charset) int {
	idx := c.rplx.add_cs(cs)

	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.span).set_aux(idx)
	c.rplx.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_test_char(ch byte, pos int) int {
	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.test_char).set_char(ch)
	c.rplx.code << pos - rtn
	return rtn
}

pub fn (mut c Compiler) add_if_char(ch byte, pos int) int {
	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.if_char).set_char(ch)
	c.rplx.code << pos - rtn
	return rtn
}

pub fn (mut c Compiler) add_choice(pos int) int {
	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.choice)
	c.rplx.code << pos - rtn
	return rtn
}

pub fn (mut c Compiler) add_partial_commit(pos int) int {
	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.partial_commit)
	c.rplx.code << pos - rtn
	return rtn
}

pub fn (mut c Compiler) add_back_commit(pos int) int {
	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.back_commit)
	c.rplx.code << pos - rtn
	return rtn
}

pub fn (mut c Compiler) add_any() int {
	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.any)
	c.rplx.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_commit(pos int) int {
	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.commit)
	c.rplx.code << pos - rtn
	return rtn
}

pub fn (mut c Compiler) add_call(fn_pos int, fn_name string) int {
	idx := c.rplx.symbols.add(fn_name)

	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.call).set_aux(idx)
	c.rplx.code << fn_pos - rtn
	return rtn
}

pub fn (mut c Compiler) add_jmp(pos int) int {
	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.jmp)
	c.rplx.code << pos - rtn
	return rtn
}

pub fn (mut c Compiler) add_set(cs rosie.Charset) int {
	idx := c.rplx.add_cs(cs)

	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.set).set_aux(idx)
	c.rplx.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_until_set(cs rosie.Charset) int {
	idx := c.rplx.add_cs(cs)

	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.until_set).set_aux(idx)
	c.rplx.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_test_set(cs rosie.Charset, pos int) int {
	idx := c.rplx.add_cs(cs)

	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.test_set).set_aux(idx)
	c.rplx.code << pos - rtn
	return rtn
}

pub fn (mut c Compiler) add_if_str(str string, pos int) int {
	idx := c.rplx.symbols.add(str)

	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.if_str).set_aux(idx)
	c.rplx.code << pos - rtn
	return rtn
}

pub fn (mut c Compiler) add_str(str string) int {
	idx := c.rplx.symbols.add(str)

	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.str).set_aux(idx)
	c.rplx.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_message(str string) int {
	idx := c.rplx.symbols.add(str)
	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.message).set_aux(idx)
	c.rplx.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_backref(name string) ? int {
	idx := c.rplx.symbols.find(name) or {
		return error("Unable to find back-referenced binding in symbol table: '$name'")
	}

	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.backref).set_aux(idx)
	c.rplx.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_register_recursive(name string) int {
	idx := c.rplx.symbols.add(name)
	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.register_recursive).set_aux(idx)
	c.rplx.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_word_boundary() int {
	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.word_boundary)
	c.rplx.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_dot_instr() int {
	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.dot)
	c.rplx.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_halt() int {
	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.halt)
	c.rplx.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_bit_7() int {
	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.bit_7)
	c.rplx.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) add_halt_capture() int {
	rtn := c.rplx.code.len
	c.rplx.code << rt.opcode_to_slot(.halt_capture)
	c.rplx.code << rt.Slot(0)
	return rtn
}

pub fn (mut c Compiler) update_addr(pc int, pos int) {
	c.rplx.code[pc + 1] = pos - pc
}
