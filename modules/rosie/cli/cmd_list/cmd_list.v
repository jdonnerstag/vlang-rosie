module cmd_list

import rosie.cli.core

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
    count := 0

    println("")
    println("Name                     Cap? Type     Color           Source")
    println("------------------------ ---- -------- --------------- -------------------------")

    // List all names registered with "main"
    // TODO We don't have that right now. But it is useful, because of name collision detection

    println("")
    println("$count/$count names shown")
    println("")
}
