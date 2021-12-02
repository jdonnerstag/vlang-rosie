
module engine

import rosie
import rosie.parser.core_0 as parser
import rosie.compiler
import rosie.runtime_v2 as rt


pub struct Engine {
pub:
	debug int

pub mut:
	package_cache 	 rosie.PackageCache
	parser 			 rosie.Parser		// TODO parserCompiler is hardcoded and can be replaced with an alternate implementation
	// optimizer OptimizerInterface
	compiler 		 compiler.Compiler	// TODO Compiler is hardcoded and can be replaced with an alternate implementation
	rplx			 rt.Rplx			// TODO Currently runtime_v2 is hardcoded and can not be replaced
	matcher 		 rt.Match
}

pub struct FnEngineOptions {
	debug int
}

pub fn new_engine(args FnEngineOptions) ? Engine {
	return Engine {
		debug: args.debug
		parser: parser.new_parser(debug: 0)?
	}
}

pub fn (mut e Engine) parse(args rosie.ParserOptions) ? {
	return e.parser.parse(args)
}

pub fn (e Engine) binding(name string) ? &rosie.Binding {
	return e.parser.binding(name)
}

pub fn (e Engine) pattern(name string) ? &rosie.Pattern {
	return &e.parser.binding(name)?.pattern
}

pub fn (mut e Engine) new_compiler(unit_test bool, debug int) compiler.Compiler {
	return compiler.new_compiler(e.parser, unit_test, debug)
}

// User may override which variables are captured. (back-refs are always captured)
pub fn (mut e Engine) compile(varname string, user_captures []string, unit_test bool, debug int) ? {
	e.compiler = e.new_compiler(unit_test, debug)
	e.compiler.compile(varname)?
	e.compiler.user_captures = user_captures		// TODO use struct for args
}

[params]
pub struct FnParseAndCompileOptions {
	rpl string
	name string
	debug int
	unit_test bool
	captures []string
}

pub fn (mut e Engine) parse_and_compile(args FnParseAndCompileOptions) ? rt.Rplx {
	if args.debug > 0 { eprintln("Parse and compile: '$args.rpl' ${'-'.repeat(40)}") }
	e.parse(data: args.rpl)?
	if args.debug > 1 { eprintln(e.binding(args.name)?.repr()) }

	if args.debug > 0 { eprintln("Expand parsed input for binding: '$args.name'") }
	e.parser.expand(args.name)?
	if args.debug > 1 { eprintln(e.binding(args.name)?.repr()) }

	if args.debug > 0 { eprintln("Compile pattern for binding: '$args.name'") }
	e.compile(args.name, [], args.unit_test, args.debug)?
	if args.debug > 0 {	e.compiler.rplx.disassemble() }

	return e.compiler.rplx
}

pub fn (e Engine) disassemble() {
	e.compiler.rplx.disassemble()
}

[params]
pub struct FnNewMatchOptions {
	debug int
}

pub fn (mut e Engine) new_match(args FnNewMatchOptions) rt.Match {
	e.matcher = rt.new_match(rplx: e.compiler.rplx, debug: args.debug)
	return e.matcher
}

pub fn (mut e Engine) match_input(data string, args FnNewMatchOptions) ? bool {
	e.new_match(args)
	return e.matcher.vm_match(data)
}

[params]
pub struct FnMatchOptions {
	name string = "*"
	debug int
	unit_test bool
}

pub fn (mut e Engine) match_(rpl string, data string, args FnMatchOptions) ? bool {
	e.parse_and_compile(rpl: rpl, name: args.name, debug: args.debug, unit_test: args.unit_test)?
	return e.match_input(data, debug: args.debug)
}

pub fn (e Engine) has_match(pname string) bool {
	return e.matcher.has_match(pname)
}

pub fn (e Engine) get_match(path ...string) ?string {
	return e.matcher.get_match_by(...path)
}

pub fn (e Engine) get_all_matches(path ...string) ? []string {
	return e.matcher.get_all_match_by(...path)
}

// replace Replace the main pattern match
fn (mut e Engine) replace(repl string) string {
	return e.matcher.replace(repl)
}

// replace Replace the pattern match identified by name
fn (mut e Engine) replace_by(name string, repl string) ?string {
	return e.matcher.replace_by(name, repl)
}

fn match_(rpl string, data string, args FnMatchOptions) ? bool {
	mut rosie := engine.new_engine(debug: args.debug)?
	return rosie.match_(rpl, data, args)
}
