module rcli

import os
import cli
import rosie
import rosie.expander
import rosie.compiler.v2 as compiler
import rosie.parser

pub fn cmd_compile(cmd cli.Command) ? {
	rosie := init_rosie_with_cmd(cmd) ?
	debug := 0

	in_file := cmd.args[0]
	mut out_file := cmd.flags.get_string('output')?
	if out_file.len == 0 {
		out_file = in_file + "x"
	}

	mut language_str := cmd.flags.get_string('language')?
	if language_str.len == 0 {
		language_str = "1.3"
	}
	if language_str !in ["stage_0", "1.3", "3.0"] {
		return error("Invalid value for 'language': ${language_str}. Choose one of 'stage_0', '1.3', '3.0'")
	}

	entrypoints := if cmd.args.len > 1 {
		cmd.args[1..]
	} else {
		["*"]
	}

	println("Info: Input: $in_file")
	println("Info: Output: $out_file")
	println("Info: Entrypoints: $entrypoints")
	println("Info: Language: $language_str")

	// TODO Add a cli option to pre-select the language / parser
	mut p := parser.new_parser(language: language_str, debug: debug)?
	if os.is_file(in_file) == false {
		pat_str := rosie.rpl + cmd.args[0]
		//eprintln("rpl: '$pat_str'")
		p.parse(data: pat_str)?
	} else {
		p.parse(file: in_file)?
	}

	mut e := expander.new_expander(main: p.parser.main, debug: debug, unit_test: false)
	for name in entrypoints {
		e.expand(name)?
	}

	mut c := compiler.new_compiler(p.parser.main, unit_test: false, debug: debug)
	for name in entrypoints {
		c.compile(name)?
	}

	c.rplx.save(out_file, true)?
}
