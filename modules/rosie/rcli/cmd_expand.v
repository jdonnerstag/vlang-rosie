module rcli

import cli
import rosie.parser.stage_0 as parser
import rosie.expander

pub fn cmd_expand(cmd cli.Command) ? {
	rosie := init_rosie_with_cmd(cmd) ?

	mut pat_str := rosie.rpl + cmd.args[0]
	mut p := parser.new_parser(debug: 0) ?
	p.parse(data: pat_str) ?

	mut e := expander.new_expander(main: p.main, debug: p.debug, unit_test: false)
	e.expand("*")?

	println(p.pattern("*")?.repr())
}
