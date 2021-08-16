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

enum TestOp { accept reject include exclude }

struct RplTest {
pub:
	line string
	line_no int
pub mut:
	pat_name string		// The binding to test
	local bool			// if true, accept local bindings
	op TestOp
	sub_pat string
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
	// Load the RPL used to parse the test instruction
	rplx := load_unittest_rpl_file(0)?

	mut f := RplFile{ fpath: fpath }
	for line_no, line in os.read_lines(fpath)? {
		if line.starts_with("-- test ") == false {
			continue
		}

		eprintln("'$line'")
		mut t := RplTest{ line: line, line_no: line_no }

		mut m := rt.new_match(rplx, 0)
		if m.vm_match(line) == false {
			return error("Not a valid rpl-test instruction: ($line_no) $fpath")
		}
		t.local = m.has_match("slocal")
		t.pat_name = m.get_match_by("pat")?
		if m.has_match("accept") == true { t.op = .accept }
		if m.has_match("reject") == true { t.op = .reject }
		if m.has_match("include") == true {
			t.op = .include
			t.sub_pat = m.get_match_by("include", "pat")?
		}
		if m.has_match("exclude") == true {
			t.op = .exclude
			t.sub_pat = m.get_match_by("exclude", "pat")?
		}
		t.input = m.get_all_match_by("input")?.map(it[1 .. it.len - 1])

		f.tests << t
	}

	return f
}

pub fn (mut f RplFile) run_tests(debug int) ? {
	mut p := parser.new_parser(fpath: f.fpath, debug: debug)?
	p.parse()?
	//if debug > 0 { eprintln(p.package.bindings) }

	for t in f.tests {
		eprintln("File: $f.fpath, pat='$t.pat_name', package: '$p.package'")

		mut c := compiler.new_compiler(p)
		c.compile(t.pat_name)?
    	rplx := rt.Rplx{ symbols: c.symbols, code: c.code }

		break
	}
}

fn load_unittest_rpl_file(debug int) ? rt.Rplx {
	fpath := "rosie_unittest.rpl"
	data := unittest_rpl
	mut p := parser.new_parser(data: data, fpath: fpath, debug: debug)?
	p.parse()?
	//if debug > 0 { eprintln(p.package.bindings) }

	mut c := compiler.new_compiler(p)
	c.compile("unittest")?

    rplx := rt.Rplx{ symbols: c.symbols, code: c.code }
	return rplx
}

const unittest_rpl = '
	import id
	import word

	alias wb = [:space:]+
	pat = id.id1
	slocal = "local"   -- local is a reserved word in RPL
	accept = "accepts"
	reject = "rejects"
	include = "includes" pat
	exclude = "excludes" pat
	input = word.q

	-- unittest = { "--" wb "test" wb {slocal wb}? pat wb {accept / reject / include / exclude} wb input {wb* "," wb* input}*
	-- ERROR: (..) is not adding a word boundary after the bracket ??
	unittest = "--" "test" (slocal)? pat (accept / reject / include / exclude) ~ input (input)*
'
