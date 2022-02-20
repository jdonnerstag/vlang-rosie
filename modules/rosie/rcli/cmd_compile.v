module rcli

import os
import cli
import time
import rosie
import rosie.engine
import rosie.compiler.vm_v2 as compiler_vm
import rosie.compiler.vlang as compiler_vlang

pub fn cmd_compile(cmd cli.Command) ? {
	mut t1 := time.new_stopwatch(auto_start: true)
	mut t2 := t1

	rosie := init_rosie_with_cmd(cmd) ?
	debug := 0
	flags := cmd.flags.get_all_found()

	show_timings := flags.get_bool('show_timings') or { false }

	in_file := cmd.args[0]
	mut out_file := flags.get_string('output') or {	"" }

	language_str := flags.get_string('language') or { "1.3" }
	if language_str !in ["stage_0", "1.3", "3.0"] {
		return error("Invalid value for 'language': ${language_str}. Choose one of 'stage_0', '1.3', '3.0'")
	}

	compiler_str := flags.get_string('compiler') or { "vm" }
	if compiler_str !in ["vm", "vlang"] {
		return error("Invalid value for 'compiler': ${compiler_str}. Choose one of 'vm', 'vlang'")
	}

	entrypoints := if cmd.args.len > 1 {
		cmd.args[1..]
	} else {
		["*"]
	}

	if out_file.len == 0 {
		if compiler_str == "vm" {
			out_file = in_file + "x"
		} else {
			return error("Config error: -o <dir> is required with compiler 'vlang'")
		}
	}

	println("Info: Input: $in_file")
	println("Info: Output: $out_file")
	println("Info: Entrypoints: $entrypoints")
	println("Info: Language: $language_str")
	println("Info: Compiler: $compiler_str")
	println("")

	if show_timings == true {
		eprintln("Timing: init: ${t1.elapsed().microseconds()} µs")
		t1.restart()
	}

	compiler := if compiler_str == "vm" {
		compiler_vm.new_compiler()?
	} else {
		compiler_vlang.new_compiler()?
	}

	mut e := engine.new_engine(language: language_str, compiler: compiler, debug: 0)?

	if os.is_file(in_file) == false {
		pat_str := rosie.rpl + cmd.args[0]
		//eprintln("rpl: '$pat_str'")
		e.prepare(rpl: pat_str, entrypoints: entrypoints, show_timings: show_timings, debug: debug, unit_test: false)?
	} else {
		e.prepare(file: in_file, entrypoints: entrypoints, show_timings: show_timings, debug: debug, unit_test: false)?
	}

	t1.restart()
	e.rplx.save(out_file, true)?
	if show_timings == true {
		eprintln("Timing: rplx saved: ${t1.elapsed().microseconds()} µs")
		eprintln("Timing: finished: ${t2.elapsed().microseconds()} µs")
	}
}
