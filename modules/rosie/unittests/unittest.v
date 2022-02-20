module unittests

import os
import rosie.runtimes.v2 as rt
import rosie.compiler.vm_v2 as compiler
import rosie.parser
import rosie.expander
import ystrconv

struct RplFile {
pub mut:
	fpath         string
	tests         []RplTest
	results       []TestResult
	failure_count int
	success_count int
}

enum TestOp {
	accept
	reject
	include
	exclude
	assertion
}

struct RplTest {
pub:
	line    string
	line_no int

pub mut:
	pat_name string // The binding to test
	local    bool   // if true, accept local bindings
	op       TestOp
	sub_pat  string
	input    []string // One or more input pattern to test against
}

struct TestResult {
pub mut:
	test_idx int
	input    string
	success  bool
	comment  string
}

pub fn read_file(fpath string) ? RplFile {
	$if bootstrap ? {
		panic("With -d bootstrap, you can not execute unittests")
		return none
	} $else {
		// Load the RPL used to parse the test instruction
		rplx := load_rplx() ?

		mut f := RplFile{ fpath: fpath }
		for line_no, line in os.read_lines(fpath)? {
			if line.starts_with('-- test ') == false {
				continue
			}

			// eprintln("'$line'")
			mut m := rt.new_match(rplx: rplx, debug: 0)
			if m.vm_match(input: line)? == false {
				return error("Not a valid rpl-test instruction: line_no=${line_no + 1}; line='${line}', file=$fpath")
			}
			f.tests << f.to_rpl_test(m, line: line, line_no: line_no + 1) ?
		}

		return f
	}
}

fn (mut f RplFile) to_rpl_test(m rt.Match, args RplTest) ?RplTest {
	mut t := args

	t.local = m.has_match('slocal')
	t.pat_name = m.get_match('pat') ?
	if m.has_match('accept') == true {
		t.op = .accept
	} else if m.has_match('reject') == true {
		t.op = .reject
	} else if m.has_match('include') == true {
		t.op = .include
		t.sub_pat = m.get_match('include', 'subpat') ?
	} else if m.has_match('exclude') == true {
		t.op = .exclude
		t.sub_pat = m.get_match('exclude', 'subpat') ?
	} else if m.has_match('assert') == true {
		t.op = .assertion
	} else {
		panic("Expected to find one of 'accept', 'reject', 'include', 'exclude', 'assert'")
	}

	t.input.clear()
	for x in m.get_all_matches('input') ? {
		str1 := x[1..x.len - 1]
		str2 := ystrconv.interpolate_double_quoted_string(str1, '') ?
		t.input << str2
		//eprintln("input: ${str1.bytes()} => ${str2.bytes()}")
	}

	// eprintln("inputs: '$t.input'")

	return t
}

pub fn (mut f RplFile) run_tests(debug int) ? {
	eprintln('-'.repeat(80))
	eprintln('Run RPL unittests for: $f.fpath')
	if f.tests.len == 0 {
		eprintln('WARNING: File does not contain any unittests')
		return
	}

	mut p := parser.new_parser(debug: debug) ?
	p.parse(file: f.fpath)?
	//p.parser.main.print_bindings()

	for i, t in f.tests {
		mut e := expander.new_expander(main: p.parser.main, debug: debug, unit_test: true)
		e.expand(t.pat_name)?

		mut c := compiler.new_compiler(p.parser.main, debug: debug, unit_test: true)?
		c.compile(t.pat_name)?

		rplx := c.rplx

		mut msg := ''
		mut xinput := ''
		for j := 0; j < t.input.len; j++ {
			input := t.input[j]
			//eprintln("Test: pattern='$t.pat_name', op='$t.op', input='$input', line=$t.line_no")

			xinput = input
			mut m := rt.new_match(rplx: rplx, debug: debug)
			m.package = p.parser.main.name
			matched := m.vm_match(input: input)?
			if t.op == .reject {
				if matched == true && m.pos == input.len {
					msg = 'expected rejection'
					break
				}
				continue
			} else if t.op == .assertion {
				if matched == false || m.input[..m.pos] != t.input[j+1] {
					msg = 'assertion failed'
					break
				}
				j += 1
				continue
			}

			if matched == false || m.pos != input.len {
				eprintln("matched: $matched, m.pos: $m.pos, input.len: $input.len, '$input'")
				msg = 'expected exact match'
				break
			}

			if t.op == .include && m.has_match(t.sub_pat) == false {
				msg = "expected to find sub-pattern '$t.sub_pat'"
				break
			} else if t.op == .exclude && m.has_match(t.sub_pat) == true {
				msg = "found unexpected sub-pattern '$t.sub_pat'"
				break
			}
		}

		if msg.len > 0 {
			f.failure_count += 1
			f.results << TestResult{
				test_idx: i
				input: xinput
				success: false
				comment: msg
			}
			eprintln("Test failed: $msg: input='$xinput', pattern='$t.pat_name', line=$t.line_no")
			// p.package().print_bindings()
		} else {
			f.success_count += 1
			f.results << TestResult{
				test_idx: i
				success: true
			}
		}
	}
}

fn is_rpl_file_newer(rpl_fname string) bool {
	rplx_fname := rpl_fname + "x"
	if os.is_file(rplx_fname) == false {
		return false
	}

	if os.is_file(rpl_fname) == false {
		return true
	}

	rpl := os.file_last_mod_unix(rpl_fname)
	rplx := os.file_last_mod_unix(rplx_fname)

	if rpl < rplx {
		return true
	}

	eprintln("WARNING: rplx-File is not up-to-date: file=$rpl_fname, rpl=$rpl >= rplx=$rplx")
	return false
}

fn load_rplx() ? &rt.Rplx {

	fname := "./modules/rosie/unittests/unittest.rpl"
	if is_rpl_file_newer(fname) == false {
		panic("Please run 'rosie_cli.exe --norcfile compile -l stage_0 $fname unittest' to rebuild the *.rplx file")
	}

	rplx_data := $embed_file("unittest.rplx").to_bytes()
	return rt.rplx_load_data(rplx_data)
}
