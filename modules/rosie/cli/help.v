module cli

const vmod_version = get_version()

pub struct CmdHelp {
pub:
    name string = "help"
}

pub fn (c CmdHelp) read_args(args []string) {}

pub fn (c CmdHelp) run() {
    data := $embed_file('help.txt')
    text := data.to_string().replace_each([
        "@exe_name", "vlang-rosie",
        "@version", vmod_version
    ])

    println(text)
}

// TODO See the issues I raised with V to fix some issues around $tmpl
// 1) Only working with return $tmpl(..)
// 2) All leading spaces are stripped from each line in the text files
pub fn (c CmdHelp) xxx() string {
    version := "0.1.0"  // TODO read from v.mod
    exe_name := "vlang-rosie"
    return $tmpl('help.txt')
}

fn get_version() string {
    data := $embed_file('v.mod')
    for line in data.to_string().split_into_lines() {
        x := line.trim_space()
        if x.starts_with("version:") {
            s := x.all_after("'").all_before("'")
            return s
        }
    }
    return "<unknown>"
}
