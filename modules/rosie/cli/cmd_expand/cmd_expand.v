module cmd_expand

import os
import flag
import rosie.cli.core
import rosie.parser


pub struct CmdExpand {}

pub fn (c CmdExpand) run(main core.MainArgs) ? {
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

	mut p := parser.new_parser(data: pat_str, debug: 0)?
	p.parse()?
	mut np := p.expand("*")?
    println(np.repr())
}

pub fn (c CmdExpand) print_help() {
    data := $embed_file('help.txt')
    text := data.to_string().replace_each([
        "@exe_name", "vlang-rosie",
    ])

    println(text)
}
