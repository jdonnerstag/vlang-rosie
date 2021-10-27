module rcli

import cli
import rosie.parser

pub fn cmd_expand(cmd cli.Command) ? {
	rosie := init_rosie_with_cmd(cmd) ?

	mut pat_str := rosie.rpl + cmd.args[0]
	mut p := parser.new_parser(data: pat_str, debug: 0) ?
	p.parse() ?
	mut np := p.expand('*') ?
	println(np.repr())
}