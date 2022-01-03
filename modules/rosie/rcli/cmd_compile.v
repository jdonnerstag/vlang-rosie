module rcli

import cli
import rosie.compiler.v2 as compiler
import rosie.parser.core_0 as parser

pub fn cmd_compile(cmd cli.Command) ? {
	rosie := init_rosie_with_cmd(cmd) ?
	debug := 0

	mut pat_str := rosie.rpl + cmd.args[0]
	fname := cmd.args[1]
	entrypoints := if cmd.args.len > 2 {
		cmd.args[2..]
	} else {
		["*"]
	}

	eprintln("rpl: '$pat_str'")
	mut p := parser.new_parser(debug: debug)?
	p.parse(data: pat_str)?

	for e in entrypoints {
		p.expand(e)?
	}

	mut c := compiler.new_compiler(p.main, unit_test: false, debug: debug)
	for e in entrypoints {
		c.compile(e)?
	}

	c.rplx.save(fname, true)?
}
