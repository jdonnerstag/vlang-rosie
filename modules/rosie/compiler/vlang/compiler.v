module vlang

import os
import rosie

struct Compiler {
pub:
	target_dir string
	module_name string
	out_file string
	unit_test bool				// When compiling for unit tests, then capture ALL variables (incl. alias)

pub mut:
	current &rosie.Package		// The current package context: either "main" or a grammar package
	debug int
	indent_level int
	user_captures []string		// User may override which variables are captured. (back-refs are always captured)

	result string				// TODO only interim; and use StringBuilder
	fragments map[string]string
}

[params]
pub struct FnNewCompilerOptions {
	user_captures []string
	unit_test bool
	debug int
	indent_level int = 2
}

pub fn new_compiler(main &rosie.Package, args FnNewCompilerOptions) ? Compiler {
	module_name := "mytest"
	target_dir := "./temp/gen/modules"
	out_file := "mytest"

	mut c := Compiler{
		target_dir: target_dir
		module_name: module_name
		out_file: "$target_dir/$module_name/$out_file"
		current: main
		debug: args.debug
		indent_level: args.indent_level
		unit_test: args.unit_test
		user_captures: args.user_captures
	}

	c.copy_template_file()?
	c.init_result()

	return c
}

fn (mut c Compiler) init_result() {
	c.result = "
module $c.module_name

import rosie
"
}

fn (mut c Compiler) write_vlang_file(fname string) ? {
	eprintln("INFO: Write file: $fname")
	mut fd := os.open_file(fname, "w")?
	defer { fd.close() }

	fd.write_string("module $c.module_name\n\n")?
	fd.write_string("// To include the generated source code, adjust vlang's module_path\n")?
	fd.write_string("// set VMODULES=.\\modules;.\\temp\\gen\\modules\n\n")?

	for _, v in c.fragments {
		fd.write_string(v)?
	}
	fd.write_string("/* */\n")?
}

fn (mut c Compiler) finish() ? {
	fname := c.out_file.replace(".v", "") + "_1.v"
	c.write_vlang_file(fname)?

	eprintln("INFO: Format files: $fname")
	os.execute("${@VEXE} fmt -w $fname")
}

fn (c Compiler) copy_template_file() ? {
	// Copy the module runtime adjusting the module name
	mut fname := "module_template.v"
	mut in_file := os.join_path(os.dir(@FILE), fname)
	mut str := os.read_file(in_file)?
	str = str.replace("module vlang", "module $c.module_name")
	out_dir := os.dir(c.out_file)
	if os.exists(out_dir) == false {
		os.mkdir(out_dir)?
	}
	os.write_file("$out_dir/$fname", str)?
}

pub fn (c Compiler) input_len(pat rosie.Pattern) ? int {
	if pat.elem is rosie.NamePattern {
		b := c.current.get(pat.elem.name)?
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
pub fn (mut c Compiler) compile(ignore string) ? {
	// Set the context used to resolve variable names
	orig_current := c.current
	defer { c.current = orig_current }

	for b in c.current.bindings {
		c.current = orig_current
		c.compile_binding(b, true)?
	}

	c.finish()?

	// TODO this is rather for all the bindings, then a one binding with 'name' only
	// TODO hard-coded path
	c.create_test_cases("./modules/rosie/compiler/vlang/test_cases.rpl")?
}

pub fn (mut c Compiler) compile_binding(b rosie.Binding, root bool) ? {
	full_name := b.full_name()
	if full_name in c.fragments {
		return
	}
	c.fragments[full_name] = ""

	name := b.name
eprintln("compile_binding: $name; ${b.repr()}")
	if c.debug > 0 { eprintln("Compile pattern for binding='$name'") }
	_, new_current := c.current.get_bp(name)?
	orig_current := c.current
	defer { c.current = orig_current }
	c.current = new_current
	if c.debug > 0 { eprintln("Compile: current='${new_current.name}'; ${b.repr()}") }

	//eprintln("Compiler: name='$name', package='$b.package', grammar='$b.grammar', current='$c.current.name', repr=${b.pattern.repr()}")
	// ------------------------------------------

	//full_name := b.full_name()
	mut fn_name := if root { name } else { full_name }
	fn_name = fn_name.replace(".", "_").replace("*", "main").to_lower()
	mut str := "
// TODO add binding repr here
pub fn (mut m Matcher) cap_${fn_name}() bool {
start_pos := m.pos
mut match_ := true
defer { if match_ == false { m.pos = start_pos } }

mut cap := m.new_capture(start_pos)
defer { m.pop_capture(cap) }

"
	if b.recursive == true || b.func == true {
		panic("RPL vlang compiler: b.recursive and b.func are not yet implemented")
	}

	pat := b.pattern
	str += c.compile_elem(pat, pat)?
	str += "
cap.end_pos = m.pos
return true

}\n"

	c.fragments[full_name] = str
}

// PatternCompiler Interface for a (wrapper) component that stitches several other
// components together, to generate all the byte code needed for a pattern, including
// predicates and multipliers.
interface PatternCompiler {
mut:
	compile(mut c Compiler) ? string
}

fn (mut c Compiler) compile_elem(pat rosie.Pattern, alias_pat rosie.Pattern) ? string {
	eprintln("compile_elem: ${pat.repr()}")
	mut be := PatternCompiler(NullBE{})

	match pat.elem {
		rosie.LiteralPattern { be = PatternCompiler(StringBE{ pat: pat, text: pat.elem.text }) }
		rosie.NamePattern { be = PatternCompiler(AliasBE{ pat: pat, name: pat.elem.name }) }
		rosie.GroupPattern { be = PatternCompiler(GroupBE{ pat: pat, elem: pat.elem }) }
/*
		rosie.CharsetPattern { be = PatternCompiler(CharsetBE{ pat: pat, cs: pat.elem.cs }) }
		rosie.DisjunctionPattern { be = PatternCompiler(DisjunctionBE{ pat: pat, elem: pat.elem }) }
		rosie.EofPattern { be = PatternCompiler(EofBE{ pat: pat, eof: pat.elem.eof }) }
		rosie.MacroPattern { be = PatternCompiler(MacroBE{ pat: pat, elem: pat.elem }) }
		rosie.FindPattern { be = PatternCompiler(FindBE{ pat: pat, elem: pat.elem }) }
		rosie.NonePattern { return error("Pattern not initialized !!!") }
*/
		else {
			eprintln("Vlang compiler: Not yet implemented: ${pat.elem.type_name()}")
			// panic("Not yet implemented: RPL Vlang compiler backend for ${pat.elem.type_name()}")
		}
	}

	return be.compile(mut c)
}
