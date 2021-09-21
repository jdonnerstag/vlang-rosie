module cmd_help

import flag
import rosie.cli.core

pub struct CmdHelp {}

pub fn (c CmdHelp) run(main core.MainArgs) ? {
    mut fp := flag.new_flag_parser(main.cmd_args)

    // [--help]
    help := fp.bool('help', `h`, false, 'Show this help message and exit.')

    fp.finalize()?

    if help {
        print_help()
    } else {
        core.print_help()
    }
}

// TODO See the issues I raised with V to fix some issues around $tmpl
// 1) Only working with return $tmpl(..)
// 2) All leading spaces are stripped from each line in the text files
pub fn (c CmdHelp) xxx() string {
    version := "0.1.0"  // TODO read from v.mod
    exe_name := "vlang-rosie"
    return $tmpl('help.txt')
}

pub fn print_help() {
    data := $embed_file('help.txt')
    text := data.to_string().replace_each([
        "@exe_name", "vlang-rosie",
    ])

    println(text)
}