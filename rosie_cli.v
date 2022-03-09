module main

// This is rosie's command line interface (cli). Please see 'v . --help' for the full list
// of options and subcommands.

import v.vmod
import cli
import os
import rosie.rcli

fn main() {
	vm := vmod.decode(@VMOD_FILE) ?

	mut app := cli.Command{
		name: vm.name
		description: vm.description
		version: vm.version
		posix_mode: true
		flags: [
			cli.Flag{	// TODO not sure how to do -vvvv or -v 10, where 10 is optional
				flag: .bool
				name: 'verbose'
				abbrev: 'v'
				description: 'Output additional messages'
			},
			cli.Flag{
				flag: .string
				name: 'rpl'
				abbrev: ''
				description: 'inline RPL statements'
			},
			cli.Flag{
				flag: .string
				name: 'file'
				abbrev: 'f'
				description: 'Load a RPL file'
			},
			cli.Flag{
				flag: .bool
				name: 'norcfile'
				abbrev: ''
				description: 'Skip initialization file'
			},
			cli.Flag{
				flag: .string
				name: 'rcfile'
				abbrev: ''
				description: 'Explicitly define the initialization file'
			},
			cli.Flag{
				flag: .string
				name: 'libpath'
				abbrev: ''
				description: 'Directories to search for rpl modules'
			},
			cli.Flag{
				flag: .string
				name: 'colors'
				abbrev: ''
				description: 'Color/pattern assignments for color output'
			},
		]
		execute: fn (cmd cli.Command) ? {
			cmd.execute_help()
		}
		commands: [
			cli.Command{
				name: 'config'
				description: 'Print rosie configuration information'
				posix_mode: true
				execute: rcli.cmd_config
				flags: [
					cli.Flag{
						flag: .bool
						name: 'lib'
						abbrev: 'l'
						description: "List the config as if in (shared) library mode. Default: cli mode."
					},
					cli.Flag{
						flag: .bool
						name: 'color_test'
						description: "Additional print a line for each color defined"
					},
				]
			},
			cli.Command{
				name: 'list'
				description: 'List patterns, packages, and macros'
				posix_mode: true
				required_args: 0
				flags: [
					cli.Flag{
						flag: .string
						name: 'filter'
						abbrev: 'f'
						description: "List all names that have substring 'filter' (default: *)"
					},
				]
				execute: rcli.cmd_list
			},
			cli.Command{
				name: 'grep'
				description: 'In the style of Unix grep, match the pattern anywhere in each input line'
				required_args: 1
				usage: '<pattern> [<filename>] [<filename>] ...'
				posix_mode: true
				flags: grep_match_flags
				execute: rcli.cmd_grep
			},
			cli.Command{
				name: 'match'
				description: 'Match the given RPL pattern against the input'
				required_args: 1
				usage: '<pattern> [<filename>] [<filename>] ...'
				posix_mode: true
				flags: grep_match_flags
				execute: rcli.cmd_match
			},
			/*
			cli.Command {
                name: 'repl'
                description: 'Start the read-eval-print loop for interactive pattern development and debugging'
                posix_mode: true
                execute: fn (cmd cli.Command) ? {
                   println('repl subcommand')
                   return
                }
            },
			*/
			cli.Command{
				name: 'test'
				description: 'Execute pattern tests written within the target rpl file(s)'
				usage: '<filenames> [<filenames>] ...'
				posix_mode: true
				required_args: 1
				execute: rcli.cmd_test
				flags: [
					cli.Flag{
						flag: .bool
						name: 'show_timings'
						abbrev: ''
						description: "Output additional timing information per execution phase"
					},
				]
			},
			cli.Command{
				name: 'expand'
				description: 'Expand an rpl expression to see the input to the rpl compiler'
				posix_mode: true
				usage: '<expression>'
				required_args: 1
				execute: rcli.cmd_expand
			},
			cli.Command{
				name: 'disassemble'
				description: 'Print the virtual machine byte code instructions for the <expression>'
				posix_mode: true
				usage: '<expression or file path>'
				required_args: 1
				execute: rcli.cmd_disassemble
			},
			cli.Command{
				name: 'compile'
				description: 'Compile one or more patterns into a rplx file'
				posix_mode: true
				usage: '<expression or rpl-file> [<entrypoint> ..]'
				required_args: 1
				execute: rcli.cmd_compile
				flags: [
					cli.Flag{
						flag: .string
						name: 'output'
						abbrev: 'o'
						description: "Output rplx file name or module directory (V output)"
					},
					cli.Flag{
						flag: .string
						name: 'language'
						abbrev: 'l'
						description: "Select a specific language, e.g. stage_0, 1.3, 3.0"
					},
					cli.Flag{
						flag: .string
						name: 'compiler'
						abbrev: 'c'
						description: "Select the compiler, e.g. vm_v2 (default), vlang"
					},
					cli.Flag{
						flag: .bool
						name: 'show_timings'
						abbrev: ''
						description: "Output additional timing information per execution phase"
					},
				]
			},
		]
	}
	app.setup()
	app.parse(os.args)
}

const grep_match_flags = [
	cli.Flag{
		flag: .string		// TODO we are not yet supporting all these formats, and I'm not sure they all provide real value
		name: 'output'
		abbrev: 'o'
		description: 'Output style, one of: jsonpp, color, data, bool, subs, byte, json, line'
	},
	cli.Flag{
		flag: .bool
		name: 'wholefile'
		abbrev: 'f'
		description: 'Read the whole input file as single string (default: line by line)'
	},
	cli.Flag{
		flag: .bool
		name: 'all'
		abbrev: 'a'
		description: 'Output all lines, including the non-matching lines'
	},
	cli.Flag{
		flag: .bool
		name: 'fixed-strings'
		abbrev: 'F'
		description: 'Interpret the pattern as a fixed string, not an RPL pattern'
	},
	cli.Flag{
		flag: .bool
		name: 'time'
		abbrev: ''
		description: 'Time each match, writing to stderr after each output'
	},
	cli.Flag{
		flag: .bool
		name: 'profile'
		abbrev: ''
		description: 'Print instruction execution statistics (requires to compile source code with -cg)'
	},
	cli.Flag{
		flag: .bool
		name: 'trace'
		abbrev: 'c'
		description: 'Pretty print all captures that matched'
	},
	cli.Flag{
		flag: .bool
		name: 'unmatched'
		abbrev: 'u'
		description: 'Also print captures that did not match (requires --trace)'
	},
	cli.Flag{
		flag: .bool
		name: 'incl_aliases'
		abbrev: 'i'
		description: 'Enable capture also for aliases (requires --trace)'
	},
	cli.Flag{
		flag: .bool
		name: 'show_timings'
		abbrev: ''
		description: "Output additional timing information per execution phase"
	},
]
