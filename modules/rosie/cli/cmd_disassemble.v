module cli

import cli
import rosie.compiler_backend_vm as compiler

pub fn cmd_disassemble(cmd cli.Command) ? {
	rosie := init_rosie_with_cmd(cmd) ?

	mut pat_str := rosie.rpl + cmd.args[0]
	rplx := compiler.parse_and_compile(rpl: pat_str, name: '*', debug: 0) ?
	rplx.disassemble()
}
