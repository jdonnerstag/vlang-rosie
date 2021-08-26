module cli

import flag


interface Command {
    run(main MainArgs)?
}

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

pub fn determine_main_args(args []string) ? MainArgs {
    mut main_args := MainArgs{}

    mut fp := flag.new_flag_parser(args)
    fp.application('Rosie Pattern Language (RPL)')
    fp.version(vmod_version)
    fp.description('A V-lang implementation of https://rosie-lang.org/')
    fp.skip_executable()

	// [--verbose]
    main_args.verbose = fp.bool('verbose', `v`, false, 'Create verbose output')	// TODO can we have an optional 'int' for level of verbosity?

	// [--file <file>] and [-f <file>]
    main_args.file = fp.string('file', `f`, "", 'Load an RPL file')

	// [--rpl <rpl>]	// --file and --rpl are mutately exclusive
    main_args.rpl = fp.string('rpl', 0, "", 'Inline RPL statements')

	// [--norcfile]
    main_args.norcfile = fp.bool('norcfile', 0, false, 'Skip initialization file')

	// [--rpl <rpl>]
    main_args.rcfile = fp.string('rcfile', 0, "", 'Initialization file to read')

	// [--libpath <libpath>]
    main_args.libpath = fp.string('libpath', 0, "", 'Directories to search for rpl modules')

	// [--colors <colors>]
	// TODO It is unclear to me what is supported in the original implementation and how it works. There don't seem to be examples.

    // [--help]
    main_args.help = fp.bool('help', `h`, false, 'Show this help message and exit.')

    fp.allow_unknown_args()
    main_args.cmd_args = fp.finalize()?

    return main_args
}

pub fn determine_cmd(args []string) ? Command {
    if args.len > 0 {
        arg := args[0]
        match arg {
            "version" { return Command(CmdVersion{}) }
            "help" { return Command(CmdHelp{}) }
            "config" { return Command(new_config()) }
            "list" { return Command(CmdList{}) }
            "grep" { return Command(CmdGrep{}) }
            "match" { return Command(CmdMatch{}) }
            "repl" { return Command(CmdRepl{}) }
            "test" { return Command(CmdTest{}) }
            "expand" { return Command(CmdExpand{}) }
            "trace" { return Command(CmdTrace{}) }
            "rplxmatch" { return Command(CmdReplxMatch{}) }
            else { return error("ERROR: Unknown <command>: '$arg'") }
        }
    }

    return error("ERROR: Missing <command>")
}
