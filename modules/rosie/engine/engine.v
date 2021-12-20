module engine

import rosie
import rosie.parser.core_0 as parser
import rosie.compiler
import rosie.runtime_v2 as rt

type CbNewParser = fn (int) ? rosie.Parser
type CbNewCompiler = fn (&Engine) ? rosie.Parser
type CbNewOptimizer = fn (&Engine) ? rosie.Parser
type CbNewMatcher = fn (&Engine) ? rosie.Parser

pub struct Engine {
pub:
	debug int
	new_parser CbNewParser = new_parser

pub mut:
	package_cache 	&rosie.PackageCache
	parser 			 rosie.Parser
	// optimizer OptimizerInterface
	compiler 		 compiler.Compiler	// TODO Compiler is hardcoded and can not be replaced with an alternate implementation
	rplx			 rt.Rplx			// TODO Currently runtime_v2 is hardcoded and can not be replaced
	matcher 		 rt.Match
}

fn new_parser(debug int) ? rosie.Parser {
	// return rosie.Parser(parser.new_parser(debug: debug)?)	// TODO I raised in an issue. I think it is a bug. It doesn't translate into proper C-code
	p := parser.new_parser(debug: debug) or { return err }
	return rosie.Parser(p)
}

fn new_compiler(engine &Engine) ? compiler.Compiler {
	return none
}

fn new_optimizer(engine &Engine) ? rosie.Parser {
	return none
}

fn new_matcher(engine &Engine) ? rt.Match {
	return none
}

[params]
pub struct FnEngineOptions {
	debug int
	new_parser CbNewParser = new_parser
	package_cache &rosie.PackageCache = rosie.new_package_cache()
}

pub fn new_engine(args FnEngineOptions) ? Engine {
	parser := args.new_parser(args.debug)?

	return Engine {
		debug: args.debug
		new_parser: args.new_parser
		parser: parser
		package_cache: args.package_cache
	}
}

pub fn (mut e Engine) parse(args rosie.ParserOptions) ? {
	return e.parser.parse(args)
}

[params]
pub struct FnNewCompilerOptions {
	user_captures []string
	unit_test bool
	debug int
}

pub fn (mut e Engine) new_compiler(args FnNewCompilerOptions) compiler.Compiler {
	return compiler.new_compiler(e.parser, unit_test: args.unit_test, debug: args.debug)
}

// User may override which variables are captured. (back-refs are always captured)
pub fn (mut e Engine) compile(varname string, args FnNewCompilerOptions) ? {
	e.compiler = e.new_compiler(user_captures: args.user_captures, unit_test: args.unit_test, debug: args.debug)
	e.compiler.compile(varname)?
}

[params]
pub struct FnParseAndCompileOptions {
	name string
	debug int
	unit_test bool
	captures []string
}

pub fn (mut e Engine) parse_and_compile(rpl string, args FnParseAndCompileOptions) ? rt.Rplx {
	// TODO Add -show-timings ...

	if args.debug > 0 { eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}") }
	e.parse(data: rpl)?
	if args.debug > 1 { eprintln(e.binding(args.name)?.repr()) }

	if args.debug > 0 { eprintln("Expand parsed input for binding: '$args.name'") }
	e.parser.expand(args.name)?
	if args.debug > 1 { eprintln(e.binding(args.name)?.repr()) }

	if args.debug > 0 { eprintln("Compile pattern for binding: '$args.name'") }
	e.compile(args.name, user_captures: args.captures, unit_test: args.unit_test, debug: args.debug)?
	if args.debug > 0 {	e.compiler.rplx.disassemble() }

	return e.compiler.rplx
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
	e.parse_and_compile(rpl, name: args.name, debug: args.debug, unit_test: args.unit_test)?
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

pub fn (e Engine) disassemble() {
	e.compiler.rplx.disassemble()
}

pub fn (e Engine) binding(name string) ? &rosie.Binding {
	return e.parser.binding(name)
}

pub fn (e Engine) pattern(name string) ? &rosie.Pattern {
	return &e.parser.binding(name)?.pattern
}