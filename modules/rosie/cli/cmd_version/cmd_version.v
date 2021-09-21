module cmd_version

import rosie.cli.core


pub struct CmdVersion {}

pub fn (c CmdVersion) run(main core.MainArgs) ? {
    println(core.vmod_version)
}

pub fn (c CmdVersion) print_help() {
    data := $embed_file('help.txt')
    text := data.to_string().replace_each([
        "@exe_name", "vlang-rosie",
    ])

    println(text)
}
