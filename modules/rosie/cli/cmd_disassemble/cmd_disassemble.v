module cmd_disassemble

import rosie.cli.core


pub struct CmdDisassemble {}

pub fn (c CmdDisassemble) run(main core.MainArgs) ? {
    println(core.vmod_version)
}

pub fn (c CmdDisassemble) print_help() {
    data := $embed_file('help.txt')
    text := data.to_string().replace_each([
        "@exe_name", "vlang-rosie",
    ])

    println(text)
}
