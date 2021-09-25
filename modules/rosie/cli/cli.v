module cli

import flag

import rosie.cli.core
import rosie.cli.cmd_version
import rosie.cli.cmd_help
import rosie.cli.cmd_config
import rosie.cli.cmd_list
import rosie.cli.cmd_test
import rosie.cli.cmd_grep

import rosie.parser


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

pub fn determine_cmd(args []string) ? int {
    for i, arg in args {
        if arg in ["version", "help", "config", "list", "grep", "match", "repl", "test", "expand", "trace", "rplxmatch"] {
            return i
        }
    }

    return error("No <command> found")
}

pub fn run_cmd(name string, args core.MainArgs, p parser.Parser) ? {
    match name {
        "version" { cmd_version.CmdVersion{}.run(args)? }
        "help" { cmd_help.CmdHelp{}.run(args)? }
        "config" { cmd_config.new_config().run(args)? }
        "list" { cmd_list.CmdList{}.run(args)? }
        "grep" { cmd_grep.CmdGrep{}.run(args)? }
        "match" { CmdMatch{}.run(args)? }
        "repl" { CmdRepl{}.run(args)? }
        "test" { cmd_test.CmdTest{}.run(args)? }
        "expand" { CmdExpand{}.run(args)? }
        "trace" { CmdTrace{}.run(args)? }
        "rplxmatch" { CmdReplxMatch{}.run(args)? }
        else { return error("Not a valid command: '$name'") }
    }
}

// TODO I hit a compiler bug with interfaces. Which is the only reason for duplicating the code.
pub fn subcommand_help(args []string, idx int) bool {
    rest := args[(idx + 1)..]
    if rest.contains("--help") == false { return false }

    match args[idx] {
        "version" { cmd_version.CmdVersion{}.print_help() }
        "help" { cmd_help.CmdHelp{}.print_help() }
        "config" { cmd_config.new_config().print_help() }
        "list" { cmd_list.CmdList{}.print_help() }
        "grep" { cmd_grep.CmdGrep{}.print_help() }
        "match" { CmdMatch{}.print_help() }
        "repl" { CmdRepl{}.print_help() }
        "test" { cmd_test.CmdTest{}.print_help() }
        "expand" { CmdExpand{}.print_help() }
        "trace" { CmdTrace{}.print_help() }
        "rplxmatch" { CmdReplxMatch{}.print_help() }
        else { return false }
    }

    return true
}
