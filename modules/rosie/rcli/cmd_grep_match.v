module rcli

import os
import cli
import rosie.compiler_backend_vm as compiler
import rosie.runtime_v2 as rt

pub fn cmd_grep(cmd cli.Command) ? {
	cmd_grep_match(cmd, true) ?
}

pub fn cmd_match(cmd cli.Command) ? {
	cmd_grep_match(cmd, false) ?
}

pub fn cmd_grep_match(cmd cli.Command, grep bool) ? {
	rosie := init_rosie_with_cmd(cmd) ?

	mut pat_str := cmd.args[0]
	if cmd.flags.get_bool('fixed-strings') ? {
		pat_str = '"$pat_str"'
	}

	files := if cmd.args.len > 1 { cmd.args[1..] } else { ['-'] }

	print_all_lines := cmd.flags.get_bool('all') ?
	print_captures := cmd.flags.get_bool('trace') ?
	print_unmatched_captures := cmd.flags.get_bool('unmatched') ?
	print_alias_captures := cmd.flags.get_bool('incl_aliases') ?

	profile := cmd.flags.get_bool('profile') ?
	if profile {
		$if !debug {
			return error('ERROR: You must compile with -cg to enable the profiler and extra debug messages.')
		}
	}

	// TODO Would it be useful to have a "line:" macro, e.g. line:{findall:p}
	// We may also use rosie in 2 simple steps: 1. match pattern for line, and 2. findall <pattern>
	// I haven't measured it, but using "native" V functions to split into lines, is probably faster
	// pat_str = 'alias nl = {[\n\r]+ / $}; alias other_than_nl = {!nl .}; p = $pat_str; line = {{p / other_than_nl}* nl}; m = line*'
	// pat_str = 'findall:{$pat_str}'
	// TODO We may define 'find' based on 'dot', and since people are allowed to supersede the 'dot' default in their package,
	//   'find' might stop at line-end, properly consider utf-8 chars, or ...
	pat_str = if grep { '{find:{$pat_str}}+' } else { 'find:{$pat_str}' }
	pat_str = rosie.rpl + pat_str

	// Since I had issues with CLI argument that require quotes and spaces ...
	// https://github.com/jdonnerstag/vlang-lessons-learnt/wiki/Command-lines-and-how-they-handle-single-and-double-quotes
	// TODO Additionally there is a bug so that `rosie grep "\"help\"" README.md` works, but `v.exe -keepc run grep "\"help\"" README.md`
	//   does not. In the 2nd example the (inner) double quotes are removed as well. Because of this bug, you
	// currently need to do `v.exe -keepc run grep "\\\"help\\\"" README.md`
	// Also a common issue: `"c" [:alnum:]+ "i"` will not do what you expect. Rosie is always GREEDY. Must be `"c" [:alnum:]+ <"i"` instead
	rplx := compiler.parse_and_compile(
		rpl: pat_str
		name: '*'
		debug: 0
		unit_test: print_alias_captures
	) ?
	// rplx.disassemble()

	if cmd.flags.get_bool('wholefile') ? {
		mut m := rt.new_match(rplx, 0)
		for file in files {
			eprintln('file: $file')

			buf := os.read_file(file) ?
			if m.vm_match(buf) {
				print('>> to be implemented <<')
			}
		}
	} else {
		mut buf := []byte{len: 8096}
		for file in files {
			eprintln('file: $file')

			// TODO V doesn't seem to have a streaming IO system yet
			mut fd := next_file(file) ?
			mut lno := 0
			for {
				// TODO replace with m.skip_to_newline
				len := fd.read_bytes_into_newline(mut buf) ?
				if len == 0 {
					break
				}
				lno += 1

				line := buf[..len].bytestr()

				mut m := rt.new_match(rplx, 0)
				if m.vm_match(line) {
					print('${lno:5}:    match: $line')
					// eprintln("match found")
				} else if print_all_lines {
					print('${lno:5}: no match: $line')
					// eprintln("No match")
				}

				if print_captures {
					m.print_captures(!print_unmatched_captures)
				}
			}
		}
	}
}

fn next_file(file string) ?os.File {
	if file == '-' {
		return os.stdin()
	}
	if os.is_file(file) {
		return os.open_file(file, 'r')
	}

	return error("Not a file: '$file'")
}
