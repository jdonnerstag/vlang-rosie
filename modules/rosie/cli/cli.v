module cli

import flag

import rosie.cli.core
import rosie.cli.cmd_version
import rosie.cli.cmd_help
import rosie.cli.cmd_config
import rosie.cli.cmd_list
import rosie.cli.cmd_test

interface Command {
    run(main core.MainArgs)?
}

pub fn determine_main_args(args []string, idx int) ? core.MainArgs {
    mut main_args := core.MainArgs{}

    mut fp := flag.new_flag_parser(args[..idx])
    fp.application('Rosie Pattern Language (RPL)')
    fp.version(core.vmod_version)
    fp.description('A native V-lang implementation of https://rosie-lang.org/')
    fp.skip_executable()

	// [--verbose]
    main_args.verbose = fp.bool('verbose', `v`, false, 'Create verbose output')	// TODO can we have an optional 'int' for level of verbosity?

	// [--file <file>] and [-f <file>]
    main_args.file = fp.string('file', `f`, "", 'Load an RPL file')

	// [--rpl <rpl>]	// --file and --rpl are mutually exclusive
    main_args.rpl = fp.string('rpl', 0, "", 'Inline RPL statements')

	// [--norcfile]
    main_args.norcfile = fp.bool('norcfile', 0, false, 'Skip initialization file')

	// [--rcfile <rcfile>]
    main_args.rcfile = fp.string('rcfile', 0, "", 'Initialization file to read')

	// [--libpath <libpath>]
    main_args.libpath = fp.string('libpath', 0, "", 'Directories to search for rpl modules')

	// [--colors <colors>]
	// TODO It is unclear to me what is supported in the original implementation and how it works. There don't seem to be examples.

    // [--help]
    main_args.help = fp.bool('help', `h`, false, 'Show this help message and exit.')

    fp.finalize()?

    main_args.cmd_args = args[idx..]
    return main_args
}

pub fn determine_cmd(args []string) ? (int, Command) {
    for i, arg in args {
        match arg {
            "version" { return i, Command(cmd_version.CmdVersion{}) }
            "help" { return i, Command(cmd_help.CmdHelp{}) }
            "config" { return i, Command(cmd_config.new_config()) }
            "list" { return i, Command(cmd_list.CmdList{}) }
            "grep" { return i, Command(CmdGrep{}) }
            "match" { return i, Command(CmdMatch{}) }
            "repl" { return i, Command(CmdRepl{}) }
            "test" { return i, Command(cmd_test.CmdTest{}) }
            "expand" { return i, Command(CmdExpand{}) }
            "trace" { return i, Command(CmdTrace{}) }
            "rplxmatch" { return i, Command(CmdReplxMatch{}) }
            else { }
        }
    }

    return error("No <command> found")
}
