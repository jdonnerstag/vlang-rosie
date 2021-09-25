module cmd_list

import rosie.cli.core
import rosie.parser

// Example output
//
// Name                     Cap? Type     Color           Source
// ------------------------ ---- -------- --------------- -------------------------
// $                             pattern  default;bold    builtin/prelude
// .                             pattern  default;bold    builtin/prelude
// ^                             pattern  default;bold    builtin/prelude
// backref                       macro                    builtin/prelude
// ci                            macro                    builtin/prelude
// error                         function                 builtin/prelude
// find                          macro                    builtin/prelude
// findall                       macro                    builtin/prelude
// keepto                        macro                    builtin/prelude
// message                       function                 builtin/prelude
// net                           package                  net.rpl
// ~                             pattern  default;bold    builtin/prelude
//
// 12/12 names shown

pub struct CmdList {}

// List patterns, packages, and macros
pub fn (c CmdList) run(main core.MainArgs) ? {
    mut count := 0
    mut count_filtered := 0

    filter := if main.cmd_args.len > 1 { main.cmd_args[1].to_lower() } else { "" }
    eprintln("Filter: '$filter'")

    println("")
    println("Name                     Cap? Type     Color           Source")
    println("------------------------ ---- -------- --------------- -------------------------")

    // List all names registered with "main"
	p := parser.new_parser(data: "", debug: 0)?
    mut pkg := p.package()
    for k, v in pkg.imports {
        count += 1
        str := "${k:24} ${' ':4} ${'package':8} ${' ':15} ${v}"
        if filter.len == 0 || str.to_lower().contains(filter) {
            count_filtered += 1
            println(str)
        }
    }

    for {
        for b in pkg.bindings {
            count += 1
            ptype := match b.pattern.elem {
                parser.LiteralPattern { "pattern" }
                parser.CharsetPattern { "charset" }
                parser.GroupPattern { "pattern" }
                parser.DisjunctionPattern { "pattern" }
                parser.NamePattern { "name" }
                parser.EofPattern { "pattern" }
                parser.MacroPattern { "macro" }
                parser.FindPattern { "macro" }
            }

            str := "${b.name:-24} ${' ':-4} ${ptype:-8} ${' ':-15} ${b.package}"
            if filter.len == 0 || str.to_lower().contains(filter) {
                count_filtered += 1
                println(str)
            }
        }

        parent := pkg.parent
        if parent.len == 0 { break }

        pkg = p.package_cache.get(parent)?
    }

    println("")
    println("$count_filtered/$count names shown")
    println("")
}

pub fn (c CmdList) print_help() {
    data := $embed_file('help.txt')
    text := data.to_string().replace_each([
        "@exe_name", "vlang-rosie",
    ])

    println(text)
}
