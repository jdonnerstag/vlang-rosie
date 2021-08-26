module cli

const vmod_version = get_version()

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

pub struct CmdVersion {}

pub fn (c CmdVersion) run(main MainArgs) ? { println(vmod_version) }
