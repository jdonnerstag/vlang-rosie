module cmd_disassemble

import os
import flag
import rosie.compiler_backend_vm as compiler
import rosie.cli.core


pub struct CmdDisassemble {}

pub fn (c CmdDisassemble) run(main core.MainArgs) ? {
    mut fp := flag.new_flag_parser(main.cmd_args)
    fp.skip_executable()

    additional_args := fp.finalize()?

    if additional_args.len == 0 {
        eprintln("<expression> is missing")
        c.print_help()
        return
    }

    mut pat_str := additional_args[0]
    eprintln(os.args)

    rplx := compiler.parse_and_compile(rpl: pat_str, name: "*", debug: 0)?
    rplx.disassemble()
}

pub fn (c CmdDisassemble) print_help() {
    data := $embed_file('help.txt')
    text := data.to_string().replace_each([
        "@exe_name", "vlang-rosie",
    ])

    println(text)
}
