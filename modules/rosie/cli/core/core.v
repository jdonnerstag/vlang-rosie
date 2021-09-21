module core

// "core" module contains logic which otherwise would cause cyclic (module) dependencies

pub struct MainArgs {
pub mut:
    verbose bool
    file string
    rpl string
    norcfile bool
    rcfile string
    libpath string
    help bool
    cmd string
    cmd_args []string
}

pub const vmod_version = get_version()

pub fn get_version() string {
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

pub fn print_help() {
    data := $embed_file('help.txt')
    text := data.to_string().replace_each([
        "@exe_name", "vlang-rosie",
        "@version", core.vmod_version,
    ])

    println(text)
}
