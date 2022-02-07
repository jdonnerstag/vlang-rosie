module engine

import rosie
import rosie.parser.stage_0 as parser
import rosie.expander
import rosie.compiler.v2 as compiler
import rosie.runtimes.v2 as rt

// Concrete Engines may leverage different parsers, expanders, optimizers
// and compilers. The 'user' interface however should always be the same.
// TODO Define an Engine interface.
struct Engine {
pub mut:
	debug int
	unit_test bool
	user_captures []string
	package_cache &rosie.PackageCache
	package &rosie.Package = 0
	rplx rt.Rplx		// TODO Currently runtime_v2 is hardcoded and can not be replaced. Rplx should moved into rosie as re-useable.
	matcher rt.Match	// TODO Currently runtime_v2 is hardcoded and can not be replaced. Rplx should moved into rosie as re-useable.
	libpath []string
}

[params]
pub struct FnEngineOptions {
	user_captures []string
	unit_test bool
	debug int
	package_cache &rosie.PackageCache = rosie.new_package_cache()
	libpath []string = parser.init_libpath()?
}

pub fn new_engine(args FnEngineOptions) ? Engine {
	return Engine {
		user_captures: args.user_captures
		unit_test: args.unit_test
		debug: args.debug
		package_cache: args.package_cache
		libpath: args.libpath
	}
}

[params]
pub struct FnPrepareOptions {
	rpl string
	file string
	name string
	debug int
	unit_test bool
	captures []string
}

pub fn (mut e Engine) prepare(args FnPrepareOptions) ? {
	// TODO Add -show-timings ...

	debug := if args.debug > 0 { args.debug } else { e.debug }
	unit_test := e.unit_test || args.unit_test
	captures := if args.captures.len > 0 { args.captures } else { e.user_captures }
	name := if args.name.len > 0 { args.name } else { "*" }

	if debug > 0 {
		if args.rpl.len > 0 {
			eprintln("Stage: 'parse': '$args.rpl' ${'-'.repeat(40)}")
		} else {
			eprintln("Stage: 'parse': file='$args.file' ${'-'.repeat(40)}")
		}
	}

	// TODO Creating the rpl-parser, is currently quite expensive. Because we use the core-parser to create the rpl-parser.
	mut p := parser.new_parser(
		debug: debug
		package_cache: e.package_cache
		libpath: e.libpath
	)?

	p.parse(data: args.rpl, file: args.file)?
	if debug > 1 { eprintln(e.binding(args.name)?.repr()) }

	if debug > 0 { eprintln("Stage: 'expand': '$name'") }

	mut ex := expander.new_expander(main: p.main, debug: p.debug, unit_test: false)
	ex.expand(name) or {
		return error("Compiler failure in expand(): $err.msg")
	}

	e.package = p.main
	if debug > 1 { eprintln(e.binding(name)?.repr()) }

	if debug > 0 { eprintln("Stage: 'compile': '$name'") }
	mut c := compiler.new_compiler(p.main,
		rplx: &e.rplx
		user_captures: captures
		unit_test: unit_test
		debug: debug
	)

	c.compile(name)?
	if debug > 2 { c.rplx.disassemble() }
	if debug > 0 { eprintln("Stage: 'finished': '$name'") }
}

[params]
pub struct FnNewMatchOptions {
	debug int
}

pub fn (mut e Engine) new_match(args FnNewMatchOptions) rt.Match {
	e.matcher = rt.new_match(rplx: e.rplx, debug: args.debug)
	return e.matcher
}

// TODO Regex has search and match. Do we need this distinction as well?
pub fn (mut e Engine) match_(data string, args FnPrepareOptions) ? bool {
	e.prepare(args)?
	return e.match_input(data, debug: args.debug)
}

pub fn (mut e Engine) match_input(data string, args FnNewMatchOptions) ? bool {
	e.new_match(args)
	return e.matcher.vm_match(data)
}

pub fn (e Engine) has_match(pname string) bool {
	return e.matcher.has_match(pname)
}

pub fn (e Engine) get_match(path ...string) ?string {
	return e.matcher.get_match(...path)
}

pub fn (e Engine) get_all_matches(path ...string) ? []string {
	return e.matcher.get_all_matches(...path)
}

// replace Replace the main pattern match
fn (mut e Engine) replace(repl string) string {
	return e.matcher.replace(repl)
}

// replace Replace the pattern match identified by name
fn (mut e Engine) replace_by(name string, repl string) ?string {
	return e.matcher.replace_by(name, repl)
}

fn match_(data string, rpl string, args FnNewMatchOptions) ? bool {
	mut rosie := engine.new_engine(debug: args.debug)?
	return rosie.match_(data, rpl: rpl, debug: args.debug)
}

pub fn (e Engine) disassemble() {
	e.rplx.disassemble()
}

pub fn (e Engine) binding(name string) ? &rosie.Binding {
	return e.package.get(name)
}

pub fn (e Engine) pattern(name string) ? &rosie.Pattern {
	return &e.package.get(name)?.pattern
}
