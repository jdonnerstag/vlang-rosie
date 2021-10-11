module main

import v.vmod
import cli
import os
import rosie.cli as rosie_cli

fn main() {
    vm := vmod.decode(@VMOD_FILE)?

    mut app := cli.Command {
        name: vm.name
        description: vm.description
        version: vm.version
        posix_mode: true
        flags: [
            cli.Flag { flag: .bool, name: "verbose", abbrev: "v", description: "Output additional messages" },
            cli.Flag { flag: .string, name: "rpl", abbrev: "", description: "inline RPL statements" },
            cli.Flag { flag: .string, name: "file", abbrev: "f", description: "Load an RPL file" },
            cli.Flag { flag: .bool, name: "norcfile", abbrev: "", description: "Skip initialization file" },
            cli.Flag { flag: .string, name: "rcfile", abbrev: "", description: "Initialization file to read" },
            cli.Flag { flag: .string, name: "libpath", abbrev: "", description: "Directories to search for rpl modules" },
            cli.Flag { flag: .string, name: "colors", abbrev: "", description: "Color/pattern assignments for color output" },
            cli.Flag { flag: .bool, name: "profile", abbrev: "", description: "Print instruction execution statistics (requires to compile source code with -cg)" }
                // TODO Can be somehow detect that -cg has been used and panic if not, if that option is provided?
        ]
        execute: fn (cmd cli.Command) ? { cmd.execute_help() }
        commands: [
            cli.Command {
                name: 'config'
                description: 'Print rosie configuration information'
                posix_mode: true
                execute: rosie_cli.cmd_config
            },
            cli.Command {
                name: 'list'
                description: "List patterns, packages, and macros"
                posix_mode: true
                required_args: 0
                flags: [
                    cli.Flag { flag: .string, name: "filter", abbrev: "f", description: "List all names that have substring 'filter' (default: *)" },
                ]
                execute: rosie_cli.cmd_list
            },
            cli.Command {
                name: 'grep'
                description: 'In the style of Unix grep, match the pattern anywhere in each input line'
                required_args: 1,
                usage: "<pattern> [<filename>] [<filename>] ..."
                posix_mode: true
                flags: [
                    cli.Flag { flag: .string, name: "output", abbrev: "o", description: "Output style, one of: jsonpp, color, data, bool, subs, byte, json, line" },
                    cli.Flag { flag: .bool, name: "wholefile", abbrev: "f", description: "Read the whole input file as single string" },
                    cli.Flag { flag: .bool, name: "all", abbrev: "a", description: "Output non-matching lines to stderr" },
                    cli.Flag { flag: .bool, name: "fixed-strings", abbrev: "F", description: "Interpret the pattern as a fixed string, not an RPL pattern" },
                    cli.Flag { flag: .bool, name: "time", abbrev: "", description: "Time each match, writing to stderr after each output" },
                ]
                execute: rosie_cli.cmd_grep
            },
            cli.Command {
                name: 'match'
                description: 'Match the given RPL pattern against the input'
                required_args: 1,
                usage: "<pattern> [<filename>] [<filename>] ..."
                posix_mode: true
                flags: [
                    cli.Flag { flag: .string, name: "output", abbrev: "o", description: "Output style, one of: jsonpp, color, data, bool, subs, byte, json, line" },
                    cli.Flag { flag: .bool, name: "wholefile", abbrev: "f", description: "Read the whole input file as single string" },
                    cli.Flag { flag: .bool, name: "all", abbrev: "a", description: "Output non-matching lines to stderr" },
                    cli.Flag { flag: .bool, name: "fixed-strings", abbrev: "F", description: "Interpret the pattern as a fixed string, not an RPL pattern" },
                    cli.Flag { flag: .bool, name: "time", abbrev: "", description: "Time each match, writing to stderr after each output" },
                ]
                execute: rosie_cli.cmd_match
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
            cli.Command {
                name: 'test'
                description: 'Execute pattern tests written within the target rpl file(s)'
                usage: "<filenames> [<filenames>] ..."
                posix_mode: true
                required_args: 1
                execute: rosie_cli.cmd_test
            },
            cli.Command {
                name: 'expand'
                description: 'Expand an rpl expression to see the input to the rpl compiler'
                posix_mode: true
                usage: "<expression>"
                required_args: 1
                execute: rosie_cli.cmd_expand
            },
/*
            cli.Command {
                name: 'trace'
                description: 'Match while tracing all steps (generates MUCH output)'
                posix_mode: true
                execute: fn (cmd cli.Command) ? {
                   println('trace subcommand')
                   return
                }
            },
*/
/* TODO We may use this to read orig rosie rplx files and execute them.
   Might also be interesting for a performance comparison.
            cli.Command {
                name: 'rplxmatch'
                description: 'Match using the compiled pattern stored in the argument (an rplx file)  (TODO maybe better --rplx .. and similar to --rpl or -f)'
                posix_mode: true
                execute: fn (cmd cli.Command) ? {
                   println('rplxmatch subcommand')
                   return
                }
            },
*/
            cli.Command {
                name: 'disassemble'
                description: 'Print the virtual machine byte code instructions'
                posix_mode: true
                usage: "<expression>"
                required_args: 1
                execute: rosie_cli.cmd_disassemble
            },
        ]
    }
    app.setup()
    app.parse(os.args)
}
