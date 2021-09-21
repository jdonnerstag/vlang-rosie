module cmd_version

import flag
import rosie.cli.core


pub struct CmdVersion {}

pub fn (c CmdVersion) run(main core.MainArgs) ? {

    mut fp := flag.new_flag_parser(main.cmd_args)

    // [--help]
    help := fp.bool('help', `h`, false, 'Show this help message and exit.')

    fp.finalize()?

    if help {
        print_help()
    } else {
        println(core.vmod_version)
    }
}

fn print_help() {
    data := $embed_file('help.txt')
    text := data.to_string().replace_each([
        "@exe_name", "vlang-rosie",
    ])

    println(text)
}
