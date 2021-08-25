module main

import os
import rosie.cli

fn main() {
    cmd, arg_idx := cli.determine_cmd(os.args) or {
        println("ERROR: Missing <command>")
        cli.CmdHelp{}.run()
        return
    }

    args1 := os.args[.. arg_idx]
    args2 := os.args[arg_idx ..]

    main_args := cli.determine_main_args(cmd.name, args1) or{
        eprintln(err)
        cli.CmdHelp{}.run()
        return
    }

    println(main_args)

    cmd.read_args(args2)
    cmd.run()
}
