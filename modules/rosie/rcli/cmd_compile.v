module rcli

import os
import cli
import rosie
import rosie.compiler.v2 as compiler
import rosie.parser.core_0 as parser

pub fn cmd_compile(cmd cli.Command) ? {
	rosie := init_rosie_with_cmd(cmd) ?
	debug := 0

	rplx_fname := cmd.args[1]
	entrypoints := if cmd.args.len > 2 {
		cmd.args[2..]
	} else {
		["*"]
	}

	mut p := parser.new_parser(debug: debug)?
	if os.is_file(cmd.args[0]) == false {
		pat_str := rosie.rpl + cmd.args[0]
		//eprintln("rpl: '$pat_str'")
		p.parse(data: pat_str)?
	} else {
		fname := cmd.args[0]
		p.parse(file: fname)?
	}

	for e in entrypoints {
		p.expand(e)?
	}

	mut c := compiler.new_compiler(p.main, unit_test: false, debug: debug)
	for e in entrypoints {
		c.compile(e)?
	}

	c.rplx.save(rplx_fname, true)?
}
