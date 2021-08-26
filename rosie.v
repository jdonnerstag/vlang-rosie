module main

import os
import rosie.cli

fn main() {
    main_args := cli.determine_main_args(os.args) or {
        eprintln(err)
        cli.print_help()
        exit(1)
    }

    if main_args.help {
        cli.print_help()
        return
    }

    cmd := cli.determine_cmd(main_args.cmd_args) or {
        println(err.msg)
        exit(1)
    }

    cmd.run(main_args) or {
        eprintln(err.msg)
        exit(1)
    }
}
