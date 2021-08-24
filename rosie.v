module main

import os
import rosie.cli

fn main() {
    mut cmd_idx := -1
    for i, a in os.args {
        if a in cli.cmd_names {
            cmd_idx = i
            break
        }
    }

    if cmd_idx == -1 {
        println("ERROR: no <command> found")
        cli.CmdHelp{}.run()
        return
    }

    cmd := cli.cmds[cmd_idx]
    args1 := os.args[.. cmd_idx]
    args2 := os.args[cmd_idx ..]

    main_args := cli.determine_main_args(cmd.name, args1) or{
        eprintln(err)
        cli.CmdHelp{}.run()
        return
    }

    cmd.read_args(args2)
}
