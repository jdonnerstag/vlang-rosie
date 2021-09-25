module cmd_grep

import os
import io
import flag
import rosie.cli.core
import rosie.compiler_backend_vm as compiler
import rosie.runtime_v2 as rt

pub struct CmdGrep {}

pub fn (c CmdGrep) run(main core.MainArgs) ? {
    mut fp := flag.new_flag_parser(main.cmd_args)
    fp.skip_executable()

	// [--output <output>], [-o <output>]
    arg_output := fp.string('output', `o`, "", 'Output style, one of jsonpp, color, ...')

	// [--wholefile], [-w]
    arg_wholefile := fp.bool('wholefile', `w`, false, 'Read the whole input file as single string')

	// [--all], [-a]
    arg_all := fp.bool('all', `a`, false, 'Output non-matching lines to stderr')

	// [--fixed-string], [-f]
    arg_fixed_string := fp.bool('fixed-string', `f`, false, 'Interpret the pattern as fixed string, not a pattern')

	// [--time]
    arg_time := fp.bool('time', 0, false, 'Time each match')

    additional_args := fp.finalize()?

    if additional_args.len == 0 {
        eprintln("<pattern> is missing")
        c.print_help()
        return
    }

    mut pat_str := additional_args[0]
    eprintln(os.args)
    if arg_fixed_string { pat_str = '"$pat_str"' }

    files := if additional_args.len > 1 { additional_args[1..] } else { ["-"] }

    // TODO Would it be useful to have a "line:" macro, e.g. line:{findall:p}
    // We may also use rosie in 2 simple steps: 1. match pattern for line, and 2. findall <pattern>
    // I haven't measured it, but using "native" V functions to split into lines, is probably faster
    //pat_str = 'alias nl = {[\n\r]+ / $}; alias other_than_nl = {!nl .}; p = $pat_str; line = {{p / other_than_nl}* nl}; m = line*'
    // pat_str = 'findall:{$pat_str}'   // TODO findall not yet supported
    pat_str = '{find:{$pat_str} / .}*'

    // TODO Currently there is a bug in V https://github.com/vlang/v/issues/11966, literal string os.args
    //   are modified, e.g. '"e"' => ''e''
    rplx := compiler.parse_and_compile(rpl: pat_str, name: "*")?

    mut buf := []byte{ len: 8096 }
    for file in files {
        eprintln("file: $file")
        mut fd := c.next_file(file)?
        for {
            // TODO read_bytes_into_newline does not "fail" on len == 0 (== eof)
            // TODO I think applying many of the io.read_xxx() functions are not yet well "integrated" with V-lang
            len := fd.read_bytes_into_newline(mut buf)?
            if len == 0 { break }

            line := buf[.. len].bytestr()
            print(line)
            /*
            mut m := rt.new_match(rplx, 0)
            if m.vm_match(line) {
                caps := m.get_all_match_by("find:*")?
                println(caps)
            } else {

            }
            */
        }
    }
}

pub fn (c CmdGrep) next_file(file string) ? os.File {
    if file == "-" { return os.stdin() }
    if os.is_file(file) {
        return os.open_file(file, "r")
    }

    return error("Not a file: '$file'")
}

pub fn (c CmdGrep) print_help() {
    data := $embed_file('help.txt')
    text := data.to_string().replace_each([
        "@exe_name", "vlang-rosie",
    ])

    println(text)
}
