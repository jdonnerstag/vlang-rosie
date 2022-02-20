module rcli

import os
import time
import cli
import rosie.compiler.vm_v2 as compiler
import rosie.runtimes.v2 as rt

pub fn cmd_disassemble(cmd cli.Command) ? {
	rosie := init_rosie_with_cmd(cmd) ?

	if os.is_file(cmd.args[0]) == false {
		mut pat_str := rosie.rpl + cmd.args[0]
		rplx := compiler.parse_and_compile(rpl: pat_str, name: '*', debug: 0) ?
		rplx.disassemble()
	} else {
		disassemble_rplx_file(cmd.args[0])?
	}
}

// TODO Move to rosie.Rplx_file ???
pub fn disassemble_rplx_file(fname string) ? {
	rplx := rosie.Rplx_load(fname)?
	println("RPLX file: $fname")
	println("    RPLX File version: $rplx.file_version")
	println("    Created: $rplx.created (${time.unix(rplx.created).format_ss()})")
	println("    Parser: $rplx.parser_type_name")
	println("    RPL-File: $rplx.rpl_fname")

	println("Charsets:")
	for i, cs in rplx.charsets {
		println("${i + 1:5}: ${cs.repr()}")
	}
	println("Symbols:")
	for i, sy in rplx.symbols.symbols {
		println("${i + 1:5}: '${sy}'")
	}
	println("Entrypoints:")
	for i, ep in rplx.entrypoints.entries {
		println("${i + 1:5}: pc=${ep.start_pc}, symbol='${ep.name}'")
	}
	println("Byte Code Instructions:")
	rplx.disassemble()
}