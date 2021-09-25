module main

import os
import rosie.cli
import rosie.cli.core

fn main() {
    i := cli.determine_cmd(os.args) or {
        eprintln("Did not find a <command>")
        core.print_help()
        exit(1)
    }

    main_args := cli.determine_main_args(os.args, i) or {
        eprintln(err)
        core.print_help()
        exit(1)
    }

    if main_args.help {
        core.print_help()
        return
    }

    if cli.subcommand_help(os.args, i) {
        return
    }

    p := main_args.process_args() or {
        eprintln(err.msg)
        exit(1)
    }

    cli.run_cmd(os.args[i], main_args, p) or {
        eprintln(err.msg)
        exit(1)
    }
}
