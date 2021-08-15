module inline_tests

import os
import rosie.runtime_v2 as rt
import rosie.compiler_backend_vm as compiler
import rosie.parser


struct RplFile {
pub mut:
	fpath string
	tests []RplTest
	results []TestResult
}

struct RplTest {
pub:
	line string
	line_no int
pub mut:
	pat_name string		// The binding to test
	local bool			// if true, accept local bindings
	accept bool			// if true, succeed on accept; else succeed on reject
	includes string		// if len > 0, then match must include sub-match
	excludes string		// if len > 0, then match must not include sub-match
	input []string		// One or more input pattern to test against
}

struct TestResult {
pub mut:
	test_idx int
	input string
	success bool
	comment string
}

pub fn read_file(fpath string) ? RplFile {
	mut f := RplFile{ fpath: fpath }
	for line_no, line in os.read_lines(fpath)? {
		if line.starts_with("-- test ") == false {
			continue
		}

		eprintln("'$line'")
		mut t := RplTest{ line: line, line_no: line_no }

		mut x := line.split_nth(" ", 2)
		if x[0] != "--" { return error("Expected to find '--'") }

		x = x[1].split_nth(" ", 2)
		if x[0] != "test" { return error("Expected to find 'test'") }

		x = x[1].split_nth(" ", 2)
		if x[0] == "local" {
			t.local = true
			x = x[1].split_nth(" ", 2)
		}

		t.pat_name = x[0]

		x = x[1].split_nth(" ", 2)
		match x[0] {
			"accepts" { t.accept = true }
			"rejects" { t.accept = false }
			"includes" {
				x = x[1].split_nth(" ", 2)
				t.includes = x[0]
			}
			"excludes" {
				x = x[1].split_nth(" ", 2)
				t.excludes = x[0]
			}
			else {
				panic("unknown keyword in '$line' => $x")
			}
		}

		x = x[1].split_nth('"', 3)
		t.input << x[1]

		for x[2].len > 0 {
			x = x[2].split_nth('"', 3)
			if x.len < 2 { break }
			t.input << x[1]
		}

		f.tests << t
	}

	return f
}

pub fn (mut f RplFile) run_tests() ? {
	for t in f.tests {
		eprintln("File: $f.fpath,  pat='$t.pat_name'")
		rplx := compiler.parse_and_compile(f.fpath, t.pat_name, 0)?

		break
	}
}

fn load_rpl_file(debug int) ? rt.Rplx {
	fpath := "rosie_unittest.rpl"
	mut file := $embed_file("rosie_unittest.rpl")
	data := file.to_string()
	mut p := parser.new_parser(data: data, fpath: fpath, debug: debug)?
	p.parse()?
	//if debug > 0 { eprintln(p.package.bindings) }

	mut c := compiler.new_compiler(p)
	c.compile("unittest")?

    rplx := rt.Rplx{ symbols: c.symbols, code: c.code }
	return rplx
}
