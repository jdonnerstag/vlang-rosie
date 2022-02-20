module vlang

import os
import rosie

struct Compiler {
pub:
	unit_test bool				// When compiling for unit tests, then capture ALL variables (incl. alias)

pub mut:
	current &rosie.Package		// The current package context: either "main" or a grammar package
	debug int
	indent_level int
	user_captures []string		// User may override which variables are captured. (back-refs are always captured)

	result string	// TODO only interim
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

	fname := "module_template.v"
	in_file := os.join_path(os.dir(@FILE), fname)
	mut str := os.read_file(in_file)?
	str = str.replace("module vlang", "module $module_name")
	out_dir := "./temp/gen/modules/$module_name"
	out_file := "$out_dir/$fname"
	if os.exists(out_dir) == false {
		os.mkdir(out_dir)?
	}
	os.write_file(out_file, str)?

	return Compiler{
		current: main
		debug: args.debug
		indent_level: args.indent_level
		unit_test: args.unit_test
		user_captures: args.user_captures
	}
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
pub fn (mut c Compiler) compile(name string) ? {
	// Set the context used to resolve variable names
	orig_current := c.current
	defer { c.current = orig_current }

	if c.debug > 0 { eprintln("Compile pattern for binding='$name'") }
	b, new_current := c.current.get_bp(name)?
	c.current = new_current
	if c.debug > 0 { eprintln("Compile: current='${new_current.name}'; ${b.repr()}") }

	//eprintln("Compiler: name='$name', package='$b.package', grammar='$b.grammar', current='$c.current.name', repr=${b.pattern.repr()}")
	// ------------------------------------------

	if b.recursive == true || b.func == true {
		panic("RPL vlang compiler: b.recursive and b.func are not yet implemented")
	}

	full_name := b.full_name()

	pat := b.pattern
	c.compile_elem(pat, pat)?
}

// PatternCompiler Interface for a (wrapper) component that stitches several other
// components together, to generate all the byte code needed for a pattern, including
// predicates and multipliers.
interface PatternCompiler {
mut:
	compile(mut c Compiler) ?
}

fn (mut c Compiler) compile_elem(pat rosie.Pattern, alias_pat rosie.Pattern) ? {
	//eprintln("compile_elem: ${pat.repr()}")
	mut be := PatternCompiler(StringBE{})

	match pat.elem {
		rosie.LiteralPattern { be = PatternCompiler(StringBE{ pat: pat, text: pat.elem.text }) }
/*
		rosie.CharsetPattern { be = PatternCompiler(CharsetBE{ pat: pat, cs: pat.elem.cs }) }
		rosie.GroupPattern { be = PatternCompiler(GroupBE{ pat: pat, elem: pat.elem }) }
		rosie.DisjunctionPattern { be = PatternCompiler(DisjunctionBE{ pat: pat, elem: pat.elem }) }
		rosie.NamePattern { be = PatternCompiler(AliasBE{ pat: pat, name: pat.elem.name }) }
		rosie.EofPattern { be = PatternCompiler(EofBE{ pat: pat, eof: pat.elem.eof }) }
		rosie.MacroPattern { be = PatternCompiler(MacroBE{ pat: pat, elem: pat.elem }) }
		rosie.FindPattern { be = PatternCompiler(FindBE{ pat: pat, elem: pat.elem }) }
		rosie.NonePattern { return error("Pattern not initialized !!!") }
*/
		else {
			panic("Not yet implemented: RPL Vlang compiler backend for ${typeof(pat.elem).name}")
		}
	}

	be.compile(mut c)?
}
