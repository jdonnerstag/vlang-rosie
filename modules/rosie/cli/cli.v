module cli

import flag


interface Command {
    name string

    read_args(args []string)
    run()
}

pub const (
    cmds = [
        Command(CmdVersion{}),
        Command(CmdConfig{}),
        Command(CmdHelp{}),
        Command(CmdList{}),
        Command(CmdGrep{}),
        Command(CmdMatch{}),
        Command(CmdRepl{}),
        Command(CmdTest{}),
        Command(CmdExpand{}),
        Command(CmdTrace{}),
        Command(CmdReplxMatch{}),
    ]

    cmd_names = determine_cmd_names(cmds)
)

pub fn determine_cmd_names(cmd []Command) []string {
    mut ar := []string{ cap: cmd.len }
    for e in cmd { ar << e.name }
    return ar
}

struct MainArgs {
pub mut:
    verbose bool
    file string
    rpl string
    norcfile bool
    rcfile string
    libpath string
    help bool
    cmd string
}

pub fn determine_main_args(cmd string, args []string) ? MainArgs {
    mut main_args := MainArgs{ cmd: cmd }

    mut fp := flag.new_flag_parser(args)
    fp.application('Rosie Pattern Language (RPL)')
    fp.version('v0.1.8')	// TODO Could this be read from v.mod??
    fp.description('A V-lang implementation of https://rosie-lang.org/')
    fp.limit_free_args(0, 0) // comment this, if you expect arbitrary texts after the options
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

    // [<command>] ...
	// How to read the command?

	// How to process with command specific flags?

    fp.finalize()?

    return main_args
}
