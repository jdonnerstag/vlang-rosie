module rcli

import os
import cli
import strings
import rosie
import rosie.compiler.v2 as compiler
import rosie.runtimes.v2 as rt

pub fn cmd_grep(cmd cli.Command) ? {
	cmd_grep_match(cmd, true) ?
}

pub fn cmd_match(cmd cli.Command) ? {
	cmd_grep_match(cmd, false) ?
}

pub fn cmd_grep_match(cmd cli.Command, grep bool) ? {
	mut rosie := init_rosie_with_cmd(cmd) ?
eprintln("verbose: $rosie.verbose")		// TODO version cli not working??
rosie.verbose = 1
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
	pat_str = if grep { ' {find:{$pat_str}}+' } else { ' find:{$pat_str}' }
	pat_str = rosie.rpl + pat_str
	if rosie.verbose > 0 { eprintln("pat_str: '$pat_str'") }

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
		mut m := rt.new_match(rplx: rplx, debug: 0)
		for file in files {
			eprintln('file: $file')

			buf := os.read_file(file) ?
			if m.vm_match(input: buf)? {
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
				if rosie.verbose > 0 {
					mut str := line
					if str.len > 25 { str = str[.. 25] + ".." }
					str = str.replace("\n", "\\n").replace("\r", "\\r")
					eprintln("line: '${str}'")
				}
				mut m := rt.new_match(rplx: rplx, debug: 0, keep_all_captures: print_all_lines)
				if m.vm_match(input: line)? {
					// TODO colorize output
					xline := colorize_line(line, m, rosie.colors)
					print('${lno:5}:    match: $xline')
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

fn colorize_line(line string, m rt.Match, colors []rosie.Color) string {
	m.print_captures(true)
	mut str := strings.new_builder(200)
	mut cap_idx := 1
	for i, ch in line {
		if cap_idx < m.captures.len && i == m.captures[cap_idx].start_pos {
			for cap_idx < m.captures.len && i == m.captures[cap_idx].start_pos {
				cap := m.captures[cap_idx]
				if cap.matched {
					esc_str := color_match(colors, m.rplx.symbols.get(cap.idx)) or { "" }
					str.write_string(esc_str)
				}
				cap_idx ++
			}
		} else if cap_idx > 1 && i == m.captures[cap_idx - 1].end_pos {
			str.write_string("\x1b[0m")
			for cap_idx > 1 && i == m.captures[cap_idx - 1].end_pos {
				cap_idx --
			}
		}

		str.write_byte(ch)
	}

	str.write_string("\x1b[0m")
	assert cap_idx == 1
	return str.str()
}

fn color_match(colors []rosie.Color, name string) ?string {
	for c in colors {
		if c.key.len == 0 {
			return c.esc_str
		} else if c.startswith && name.starts_with(c.key) {
			return c.esc_str
		} else if name == c.key {
			return c.esc_str
		}
	}
	return none
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
