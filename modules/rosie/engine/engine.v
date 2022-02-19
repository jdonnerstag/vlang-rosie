module engine

import time
import rosie
import rosie.parser
import rosie.expander
import rosie.compiler.vm_v2 as compiler
import rosie.runtimes.v2 as rt

// Concrete Engines may leverage different parsers, expanders, optimizers
// and compilers. The 'user' interface however should always be the same.
// TODO Define an Engine interface.
struct Engine {
pub mut:
	language string		// Default parser
	debug int
	unit_test bool
	package_cache &rosie.PackageCache
	package &rosie.Package = 0
	rplx rt.Rplx		// TODO Currently runtime_v2 is hardcoded and can not be replaced. Rplx should moved into rosie as re-useable.
	matcher rt.Match	// TODO Currently runtime_v2 is hardcoded and can not be replaced. Rplx should moved into rosie as re-useable.
	libpath []string	// PATH-like list to search for *.rpl files
}

[params]
pub struct FnEngineOptions {
	language string
	unit_test bool
	debug int
	package_cache &rosie.PackageCache = rosie.new_package_cache()
	libpath []string = parser.init_libpath()?
}

pub fn new_engine(args FnEngineOptions) ? Engine {
	return Engine {
		language: args.language
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
	entrypoints []string
	debug int
	unit_test bool
	show_timings bool
	captures []string
}

// TODO regex implementation usually call this 'compile'
pub fn (mut e Engine) prepare(args FnPrepareOptions) ? {
	debug := if args.debug > 0 { args.debug } else { e.debug }
	unit_test := if args.unit_test { true } else { e.unit_test }
	captures := args.captures
	entrypoints := if args.entrypoints.len > 0 { args.entrypoints } else { ["*"] }
	show_timings := args.show_timings

	if debug > 0 {
		if args.rpl.len > 0 {
			eprintln("Stage: 'parse': '$args.rpl' ${'-'.repeat(40)}")
		} else {
			eprintln("Stage: 'parse': file='$args.file' ${'-'.repeat(40)}")
		}
	}

	mut t1 := time.new_stopwatch(auto_start: true)
	mut p := parser.new_parser(
		debug: debug
		language: e.language
		package_cache: e.package_cache
		libpath: e.libpath
	)?
	if show_timings == true {
		eprintln("Timing: new parser: ${t1.elapsed().microseconds()} µs")
		t1.restart()
	}

	p.parse(data: args.rpl, file: args.file)?
	if show_timings == true {
		eprintln("Timing: parse input: ${t1.elapsed().microseconds()} µs")
		t1.restart()
	}
	if debug > 1 {
		for name in entrypoints {
			eprintln(e.binding(name)?.repr())
		}
	}

	mut ex := expander.new_expander(main: p.parser.main, debug: debug, unit_test: unit_test)
	for name in entrypoints {
		if debug > 0 {
			eprintln("Stage: 'expand': '$name'")
		}
		ex.expand(name) or {
			return error("Compiler failure in expand(): $err.msg")
		}
		if debug > 1 {
			eprintln(e.binding(name)?.repr())
		}
	}
	if show_timings == true {
		eprintln("Timing: expand: ${t1.elapsed().microseconds()} µs")
		t1.restart()
	}

	e.package = p.parser.main

	e.rplx.rpl_fname = args.file
	e.rplx.parser_type_name = p.parser.type_name()

	mut c := compiler.new_compiler(p.parser.main,
		rplx: &e.rplx
		user_captures: captures
		unit_test: unit_test
		debug: debug
	)

	for name in entrypoints {
		if debug > 0 {
			eprintln("Stage: 'compile': '$name'")
		}
		c.compile(name)?
	}
	if show_timings == true {
		eprintln("Timing: compile: ${t1.elapsed().microseconds()} µs")
	}

	if debug > 0 { eprintln("Finished") }
	if debug > 2 { c.rplx.disassemble() }
}

[params]
pub struct FnNewMatchOptions {
	debug int
}

pub fn (mut e Engine) new_match(args FnNewMatchOptions) rt.Match {
	e.matcher = rt.new_match(rplx: e.rplx, debug: args.debug)
	return e.matcher
}

// TODO Remove
// TODO Regex has search and match. Do we need this distinction as well?
pub fn (mut e Engine) match_(data string, args FnPrepareOptions) ? bool {
	e.prepare(args)?
	return e.match_input(data, debug: args.debug)
}

// TODO Remove
pub fn (mut e Engine) match_input(data string, args FnNewMatchOptions) ? bool {
	e.new_match(args)
	return e.matcher.vm_match(input: data)
}

// TODO Remove
pub fn (e Engine) has_match(pname string) bool {
	return e.matcher.has_match(pname)
}

// TODO Remove
pub fn (e Engine) get_match(path ...string) ?string {
	return e.matcher.get_match(...path)
}

// TODO Remove
pub fn (e Engine) get_all_matches(path ...string) ? []string {
	return e.matcher.get_all_matches(...path)
}

// TODO Remove
// replace Replace the main pattern match
fn (mut e Engine) replace(repl string) string {
	return e.matcher.replace(repl)
}

// TODO Remove
// replace Replace the pattern match identified by name
fn (mut e Engine) replace_by(name string, repl string) ?string {
	return e.matcher.replace_by(name, repl)
}

// TODO Remove
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
