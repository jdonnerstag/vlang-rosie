module vlang

import os
import rosie

struct Compiler {
pub:
	rpl_file string
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
	constants []string

	binding_context CompilerBindingContext
	pattern_context CompilerPatternContext
}

struct CompilerBindingContext {
pub mut:
	current &rosie.Package		// The current package context: either "main" or a grammar package
	fn_name string				// Fn name of the current binding function name
	fn_idx int					// unique id for group function created within a binding
}

struct CompilerPatternContext {
	is_sequence bool = true		// true if "and", else "or"
	negate bool					// true for [^ ..] pattern
}

[params]
pub struct FnNewCompilerOptions {
	rpl_file string
	user_captures []string
	unit_test bool
	debug int
	indent_level int = 2
	out_dir string
}

pub fn new_compiler(main &rosie.Package, args FnNewCompilerOptions) ? Compiler {
	mut module_name := os.file_name(args.out_dir)
	target_dir := args.out_dir
	out_file := os.file_name(args.rpl_file.replace(".rpl", ".v"))

	mut c := Compiler{
		rpl_file: args.rpl_file
		target_dir: target_dir
		module_name: module_name
		out_file: "$target_dir/$out_file"
		current: main
		debug: args.debug
		indent_level: args.indent_level
		unit_test: args.unit_test
		user_captures: args.user_captures
		binding_context: CompilerBindingContext{ current: main }
		pattern_context: CompilerPatternContext{ is_sequence: true }
	}

	c.copy_template_file()?
	return c
}

fn (mut c Compiler) write_vlang_file(fname string) ? {
	eprintln("INFO: Write file: $fname")
	mut fd := os.open_file(fname, "w")?
	defer { fd.close() }

	fd.write_string("module $c.module_name\n\n")?
	fd.write_string("import rosie\n\n")?

	fd.write_string("// To include the generated source code, adjust vlang's module_path\n")?
	fd.write_string("// set VMODULES=.\\modules;.\\temp\\gen\\modules\n\n")?

	for e in c.constants {
		fd.write_string(e)?
	}

	for _, v in c.fragments {
		fd.write_string(v)?
	}
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
pub fn (mut c Compiler) compile(_ string) ? {
	// Set the context used to resolve variable names
	orig_current := c.current
	defer { c.current = orig_current }

	for b in c.current.bindings {
		c.current = orig_current
		c.compile_binding(b)?
	}

	c.finish()?

	if c.rpl_file.len > 0 {
		c.create_test_cases(c.rpl_file)?
	}
}

pub fn (mut c Compiler) compile_binding(b rosie.Binding) ? {
	full_name := b.full_name()
	if full_name in c.fragments {
		return
	}
	c.fragments[full_name] = ""

	name := b.name
	//eprintln("compile_binding: $name; ${b.repr()}")
	if c.debug > 0 { eprintln("Compile pattern for binding='$name'") }
	_, new_current := c.current.get_bp(name)?
	orig_current := c.current
	defer { c.current = orig_current }
	c.current = new_current
	if c.debug > 0 { eprintln("Compile: current='${new_current.name}'; ${b.repr()}") }

	//eprintln("Compiler: name='$name', package='$b.package', grammar='$b.grammar', current='$c.current.name', repr=${b.pattern.repr()}")
	// ------------------------------------------

	orig_binding_context := c.binding_context
	orig_pattern_context := c.pattern_context
	defer {
		c.binding_context = orig_binding_context
		c.pattern_context = orig_pattern_context
	}
	fn_name := c.cap_fn_name(b)
	c.binding_context = CompilerBindingContext{ current: c.current, fn_name: fn_name }

	mut str := "
// ${b.repr()}
pub fn (mut m Matcher) ${fn_name}() bool {
mut cap := m.new_capture(m.pos)
defer { m.pop_capture(cap) }

"
	str += "match_ := ${c.compile_elem(b.pattern)?} \n"
	str += "if match_ == true { cap.end_pos = m.pos } \n"
	str += "return match_ }\n"

	c.fragments[full_name] = str
}

// PatternCompiler Interface for a (wrapper) component that stitches several other
// components together, to generate all the byte code needed for a pattern, including
// predicates and multipliers.
interface PatternCompiler {
mut:
	compile(mut c Compiler) ? string
}

fn (c Compiler) cap_fn_name(b rosie.Binding) string {
	name := match b.name {
		"." { b.package + "_dot" }
		"$" { b.package + "_eof" }
		"^" { b.package + "_bof" }
		"*" { b.package + "_main" }
		"~" { b.package + "_word_boundary" }
		else { b.full_name() }
	}
	return "cap_${name}".replace(".", "_").to_lower()
}

fn (c Compiler) pattern_fn_name() string {
	return "${c.binding_context.fn_name}_pat_${c.binding_context.fn_idx}"
}

fn (mut c Compiler) open_pattern_fn(fn_name string, pat_str string) string {
	c.binding_context.fn_idx ++
	c.fragments[fn_name] = ""
	mut fn_str := "\n"
	fn_str += "// Pattern: ${pat_str} \n"
	fn_str += "fn (mut m Matcher) ${fn_name}() bool { start_pos := m.pos \n mut match_ := true \n"
	return fn_str
}

fn (mut c Compiler) close_pattern_fn(fn_name string, fn_str string) {
	mut str := fn_str
	str += "if match_ == false { m.pos = start_pos } \n"
	str += "return match_ \n } \n\n"

	c.fragments[fn_name] = str
}

fn (mut c Compiler) compile_elem(pat rosie.Pattern) ? string {
	//eprintln("compile_elem: ${pat.repr()}")
	mut be := PatternCompiler(NullBE{})

	match pat.elem {
		rosie.LiteralPattern { be = PatternCompiler(StringBE{ pat: pat, text: pat.elem.text }) }
		rosie.NamePattern { be = PatternCompiler(AliasBE{ pat: pat, name: pat.elem.name }) }
		rosie.CharsetPattern { be = PatternCompiler(CharsetBE{ pat: pat, cs: pat.elem.cs }) }
		rosie.GroupPattern { be = PatternCompiler(GroupBE{ pat: pat, elem: pat.elem }) }
		rosie.DisjunctionPattern { be = PatternCompiler(DisjunctionBE{ pat: pat, elem: pat.elem }) }
		rosie.EofPattern { be = PatternCompiler(EofBE{ pat: pat, eof: pat.elem.eof }) }
		rosie.MacroPattern { be = PatternCompiler(MacroBE{ pat: pat, elem: pat.elem }) }
		rosie.FindPattern { return error("There should be no more FindPattern. It should be MarcoPattern now.") }
		rosie.NonePattern { return error("Pattern not initialized !!!") }
	}

	// Every pattern gets wrapped into a function
	fn_name := c.pattern_fn_name()
	mut fn_str := c.open_pattern_fn(fn_name, pat.repr())
	fn_str += "match_ = ${be.compile(mut c)?} \n"
	c.close_pattern_fn(fn_name, fn_str)

	return "m.${fn_name}()"
}

const (
	a_true = "return true \n"
	a_false = "m.pos = start_pos \n return false \n"
)

fn (c Compiler) gen_code(pat &rosie.Pattern, cmd string) string {
	//return_true := a_true
	return_false := a_false
	mut invert := ""
	if pat.predicate == .negative_look_ahead {
		invert = "!"
	}

	mut str := "\n"
	if pat.min < 3 {
		for i := 0; i < pat.min; i++ {
			str += "match_ = ${invert}${cmd} \n"
			str += "if match_ == false { \n $return_false } \n"
		}
	} else {
		str += "for i := 0; i < $pat.min; i++ { \n"
		str += "  match_ = ${invert}${cmd} \n"
		str += "  if match_ == false { \n $return_false } \n"
		str += "} \n"
	}

	if pat.max == -1 {
		str += "for match_ == true && m.pos < m.input.len { \n"
		str += "  match_ = ${invert}${cmd} \n"
		str += "} \n"
		str += "match_ = ${invert} true \n"
	} else if pat.max > pat.min {
		str += "for i := $pat.min; (i < $pat.max) && (match_ == true); i++ { \n"
		str += "  match_ = ${invert}${cmd} \n"
		str += "} \n"
		str += "match_ = ${invert} true \n"
	}

	if pat.predicate != .na {
		str += "m.pos = start_pos \n"
	}

	return str
}
