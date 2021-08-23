module unittests

import os
import rosie.runtime_v2 as rt
import rosie.compiler_backend_vm as compiler
import rosie.parser
import ystrconv

struct RplFile {
pub mut:
	fpath string
	tests []RplTest
	results []TestResult
	failure_count int
	success_count int
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

		//eprintln("'$line'")
		mut m := rt.new_match(rplx, 0)
		if m.vm_match(line) == false {
			return error("Not a valid rpl-test instruction: line=${line_no + 1}; file=$fpath")
		}
		f.tests << f.to_rpl_test(m, line: line, line_no: line_no + 1)?
	}

	return f
}

fn (mut f RplFile) to_rpl_test(m rt.Match, args RplTest) ? RplTest {
	mut t := args

	t.local = m.has_match("slocal")
	t.pat_name = m.get_match_by("pat")?
	if m.has_match("accept") == true { t.op = .accept }
	if m.has_match("reject") == true { t.op = .reject }
	if m.has_match("include") == true {
		t.op = .include
		t.sub_pat = m.get_match_by("include", "subpat")?
	}
	if m.has_match("exclude") == true {
		t.op = .exclude
		t.sub_pat = m.get_match_by("exclude", "subpat")?
	}

	t.input.clear()
	for x in m.get_all_match_by("input")? {
		mut str := x[1 .. x.len - 1]
		str = ystrconv.interpolate_double_quoted_string(str, "")?
		t.input << str
	}

	//eprintln("inputs: '$t.input'")

	return t
}

// TODO This is a good opportunity to test multi-entrypoints
pub fn (mut f RplFile) run_tests(debug int) ? {
	eprintln("Run RPL unittests for: $f.fpath")
	mut p := parser.new_parser(fpath: f.fpath, debug: debug)?
	p.parse()?
	//if debug > 0 { eprintln(p.package.bindings) }

	for i, t in f.tests {
		mut c := compiler.new_compiler(p, debug)
		c.compile(t.pat_name)?
    	rplx := rt.Rplx{ symbols: c.symbols, code: c.code }

		mut msg := ""
		mut xinput := ""
		for input in t.input {
			//eprintln("Test: pattern='$t.pat_name', op='$t.op', input='$input', line=$t.line_no")

			xinput = input
			mut m := rt.new_match(rplx, debug)
			m.package = p.package
			matched := m.vm_match(input)
			if t.op == .reject {
				if matched == true && m.pos == input.len {	// TODO we need starts_with() and match()
					msg = "expected rejection"
					break
				}
				continue
			}

			if matched == false || m.pos != input.len {
				eprintln("matched: $matched, m.pos: $m.pos, input.len: $input.len, '$input'")
				msg = "expected acceptance"
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
			f.results << TestResult{ test_idx: i, input: xinput, success: false, comment: msg }
			eprintln("Test failed: $msg: input='$xinput', pattern='$t.pat_name', line=$t.line_no")
		} else {
			f.success_count += 1
			f.results << TestResult{ test_idx: i, success: true }
		}
	}
}

fn load_unittest_rpl_file(debug int) ? rt.Rplx {
	fpath := "rosie_unittest.rpl"
	data := unittest_rpl
	mut p := parser.new_parser(data: data, fpath: fpath, debug: debug)?
	p.parse()?
	//if debug > 0 { eprintln(p.package.bindings) }

	mut c := compiler.new_compiler(p, debug)
	c.compile("unittest")?

    rplx := rt.Rplx{ symbols: c.symbols, code: c.code }
	if debug > 0 { rplx.disassemble() }

	return rplx
}
