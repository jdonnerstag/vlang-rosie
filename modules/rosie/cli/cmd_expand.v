module cli

import cli
import rosie.parser


pub fn cmd_expand(cmd cli.Command) ? {
    mut pat_str := cmd.args[0]
	mut p := parser.new_parser(data: pat_str, debug: 0)?
	p.parse()?
	mut np := p.expand("*")?
    println(np.repr())
}
