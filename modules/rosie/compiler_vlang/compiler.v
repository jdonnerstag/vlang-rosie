module compiler_vlang

import os
import rosie.runtime_v2 as rt	// TODO Kind of an awkward dependency ?!?!
import rosie.parser


struct Compiler {
pub:
	unit_test bool				// When compiling for unit tests, then capture ALL variables (incl. alias)
	fpath string				// the generated V-file

pub mut:
	out os.File
	parser parser.Parser		// Actually we should only need all the bindings
	rplx rt.Rplx				// symbols, charsets, instructions
	func_implementations map[string]int		// function name => pc: fn entry point
	debug int
	indent_level int
	user_captures []string		// User may override which variables are captured. (back-refs are always captured)
	brackets int
}

pub fn new_compiler(p parser.Parser, unit_test bool, debug int) Compiler {
	return Compiler{
		parser: p,
		debug: debug,
		unit_test: unit_test,
		fpath: r"./temp/rosie-gen.v"
	}
}

// TODO The same for all compilers?
[inline]
pub fn (c Compiler) binding(name string) ? &parser.Binding {
	return c.parser.binding(name)
}

// TODO The same for all compilers?
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
	fn_name := if name == "*" { "main" } else { name }
	eprintln("Open file: ${c.fpath}")
	c.out = os.open_file(c.fpath, "w")?
	c.out.writeln("module vrosie")?
	c.out.writeln("")?
	c.out.writeln("pub fn vrosie_match_${fn_name}(input string, ipos int) bool {")?
	c.out.writeln("  mut pos := ipos")?

	defer {
		c.out.writeln("}".repeat(c.brackets)) or {}
		c.out.writeln("  return false") or {}
		c.out.writeln("}") or {}
		c.out.close()
	}

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
		c.add_call(func_pc, full_name)?
	} else {
		c.add_open_capture(full_name)?
		c.compile_elem(pat, pat)?
		c.add_close_capture()?
	}
	c.add_end()?
}

pub fn (mut c Compiler) compile_func_body(b parser.Binding) ? {
	full_name := b.full_name()
	if full_name in c.func_implementations {
		return
	}

	if b.recursive { c.add_register_recursive(full_name)? }

	c.add_jmp(0)?
	c.func_implementations[full_name] = c.rplx.code.len

	add_capture := b.alias == false || c.unit_test
	if add_capture { c.add_open_capture(full_name)? }

	c.add_choice(0)?

	c.compile_elem(b.pattern, b.pattern)?

	if add_capture { c.add_close_capture()? }

	c.add_ret()?
	c.add_fail_twice()?
}

fn (mut c Compiler) compile_elem(pat parser.Pattern, alias_pat parser.Pattern) ? {
	//eprintln("compile_elem: ${pat.repr()}")
	match pat.elem {
		parser.LiteralPattern {
			mut x := PatternCompiler(StringBE{ pat: pat, text: pat.elem.text })
			x.compile(mut c)?
		}
		parser.CharsetPattern { /* PatternCompiler(CharsetBE{ pat: pat, cs: pat.elem.cs }) */ }
		parser.GroupPattern { /* PatternCompiler(GroupBE{ pat: pat, elem: pat.elem }) */ }
		parser.DisjunctionPattern { /* PatternCompiler(DisjunctionBE{ pat: pat, elem: pat.elem }) */ }
		parser.NamePattern { /*
			b := c.binding(pat.elem.name)?
			PatternCompiler(AliasBE{ pat: pat, binding: b }) */
		}
		parser.EofPattern { /* PatternCompiler(EofBE{ pat: pat, eof: pat.elem.eof }) */ }
		parser.MacroPattern { /* PatternCompiler(MacroBE{ pat: pat, elem: pat.elem }) */ }
		parser.FindPattern { /* PatternCompiler(FindBE{ pat: pat, elem: pat.elem }) */ }
	}
}

pub fn (mut c Compiler) add_open_capture(name string) ? {
	//idx := c.rplx.symbols.add(name)
	c.out.writeln("open_capture('$name')")?
}

pub fn (mut c Compiler) add_behind(offset int) ? {
	c.out.writeln("x := pos + offset")?
	c.out.writeln("fail = x < 0")?
	c.out.writeln("if !fail { pos = x }")?
}

pub fn (mut c Compiler) add_close_capture() ? {
	c.out.writeln("close_capture()")?
}

pub fn (mut c Compiler) add_end() ? {
	c.out.writeln("return true")?
}

pub fn (mut c Compiler) add_digit() ? {
	c.out.writeln("fail = eof || input[bt.pos] < 48 || input[bt.pos] > 57")?
}

pub fn (mut c Compiler) add_ret() ? {
	c.out.writeln("func_rtn()")?
}

pub fn (mut c Compiler) add_fail() ? {
	c.out.writeln("fail()")?
}

pub fn (mut c Compiler) add_fail_twice() ? {
	c.out.writeln("fail_twice()")?
}

pub fn (mut c Compiler) add_test_any(pos int) ? {
	c.out.writeln("test_any()")?
	c.brackets ++
}

pub fn (mut c Compiler) add_char(ch byte) ? {
	c.out.writeln("if pos < input.len && input[pos] == $ch {")?
	c.out.writeln("  pos++")?
	c.brackets ++
}

pub fn (mut c Compiler) add_char2(str string) ? {
	c.out.writeln("add_char(`${str[0]}`)")?
	c.out.writeln("add_char(`${str[1]}`)")?
}

pub fn (mut c Compiler) add_until_char(ch byte) ? {
	c.out.writeln("until_char(`$ch`)")?
}

pub fn (mut c Compiler) add_span(cs rt.Charset) ? {
	idx := c.rplx.add_cs(cs)
	c.out.writeln("span($idx)")?
}

pub fn (mut c Compiler) add_test_char(ch byte, pos int) ? {
	c.out.writeln("if test_char(`$ch`) {")?
}

pub fn (mut c Compiler) add_if_char(ch byte, pos int) ? {
	c.out.writeln("if if_char(`$ch`) {")?
}

pub fn (mut c Compiler) add_choice(pos int) ? {
	c.out.writeln("push_stack()")?
}

pub fn (mut c Compiler) add_partial_commit(pos int) ? {
	c.out.writeln("partial_commit()")?
}

pub fn (mut c Compiler) add_back_commit(pos int) ? {
	c.out.writeln("back_commit()")?
}

pub fn (mut c Compiler) add_any() ? {
	c.out.writeln("any()")?
}

pub fn (mut c Compiler) add_commit(pos int) ? {
	c.out.writeln("commit()")?
}

pub fn (mut c Compiler) add_call(fn_pos int, fn_name string) ? {
	//idx := c.rplx.symbols.add(fn_name)
	c.out.writeln("fail = ${fn_name}()")?
}

pub fn (mut c Compiler) add_jmp(pos int) ? {
	c.out.writeln("jmp()")?
}

pub fn (mut c Compiler) add_set(cs rt.Charset) ? {
	//idx := c.rplx.add_cs(cs)
	c.out.writeln("set_cs()")?
}

pub fn (mut c Compiler) add_set_from_to(from int, to int) ? {
	c.out.writeln("set_from_to($from, $to)")?
}

pub fn (mut c Compiler) add_until_set(cs rt.Charset) ? {
	//idx := c.rplx.add_cs(cs)
	c.out.writeln("until_set()")?
}

pub fn (mut c Compiler) add_test_set(cs rt.Charset, pos int) ? {
	//idx := c.rplx.add_cs(cs)
	c.out.writeln("if test_set() {")?
}

pub fn (mut c Compiler) add_if_str(str string, pos int) ? {
	//idx := c.rplx.symbols.add(str)
	c.out.writeln("if if_str('$str') {")?
}

pub fn (mut c Compiler) add_str(str string) ? {
	//idx := c.rplx.symbols.add(str)

	c.out.writeln("str('$str')")?
}

pub fn (mut c Compiler) add_message(str string) ? {
	//idx := c.rplx.symbols.add(str)
	c.out.writeln("message('$str')")?
}

pub fn (mut c Compiler) add_backref(name string) ? {
	//idx := c.rplx.symbols.find(name) or {
	//	return error("Unable to find back-referenced binding in symbol table: '$name'")
	//}

	c.out.writeln("backref('$name')")?
}

pub fn (mut c Compiler) add_register_recursive(name string) ? {
	//idx := c.rplx.symbols.add(name)
	c.out.writeln("register_recursive('$name')")?
}

pub fn (mut c Compiler) add_word_boundary() ? {
	c.out.writeln("word_boundary()")?
}

pub fn (mut c Compiler) add_dot_instr() ? {
	c.out.writeln("dot_instr()")?
}

pub fn (mut c Compiler) add_bit_7() ? {
	c.out.writeln("bit_7()")?
}
