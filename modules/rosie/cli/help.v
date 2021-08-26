module cli

pub struct CmdHelp {}

pub fn (c CmdHelp) run(main MainArgs) ? { print_help() }

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
        "@version", vmod_version
    ])

    println(text)
}