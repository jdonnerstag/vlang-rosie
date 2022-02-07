module unittests

import os
import ystrconv
import rosie.runtimes.v2 as rt

const rpl_dir = os.dir(@FILE) + '/../../../rpl'

fn test_load_unittest() ? {
	rplx := load_unittest_rpl_file(0) ?
	mut line := '-- test mypat accepts "test"'
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.has_match('slocal') == false
	assert m.get_match('pat') ? == 'mypat'
	assert m.has_match('accept') == true
	assert m.has_match('reject') == false
	assert m.has_match('include') == false
	assert m.has_match('exclude') == false
	assert m.get_match('input') ? == '"test"'
}

fn test_multiple_inputs() ? {
	rplx := load_unittest_rpl_file(0) ?
	mut line := '-- test local mypat rejects "test", "abc"'
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.has_match('slocal') == true
	assert m.get_match('pat') ? == 'mypat'
	assert m.has_match('accept') == false
	assert m.has_match('reject') == true
	assert m.has_match('include') == false
	assert m.has_match('exclude') == false
	assert m.get_match('input') ? == '"test"'
	assert m.get_all_matches('input') ? == ['"test"', '"abc"']
}

fn test_include() ? {
	rplx := load_unittest_rpl_file(0) ?

	mut line := '-- test mypat includes abc "test"'
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.has_match('slocal') == false
	assert m.get_match('pat') ? == 'mypat'
	assert m.has_match('accept') == false
	assert m.has_match('reject') == false
	assert m.has_match('include') == true
	assert m.has_match('exclude') == false
	assert m.get_match('input') ? == '"test"'
	assert m.get_match('include', 'subpat') ? == 'abc'
}

fn test_include_dotted() ? {
	rplx := load_unittest_rpl_file(0) ?

	mut line := '-- test mypat includes abc.def "test"'
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.has_match('slocal') == false
	assert m.get_match('pat') ? == 'mypat'
	assert m.has_match('accept') == false
	assert m.has_match('reject') == false
	assert m.has_match('include') == true
	assert m.has_match('exclude') == false
	assert m.get_match('input') ? == '"test"'
	assert m.get_match('include', 'subpat') ? == 'abc.def'
}

fn test_escaped_quoted_string() ? {
	rplx := load_unittest_rpl_file(0) ?

	mut line := r'-- test value accepts "\"hello\"", "\"this string has \\\"embedded\\\" double quotes\""'

	// eprintln("line='$line'")
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.has_match('slocal') == false
	assert m.get_match('pat') ? == 'value'
	assert m.has_match('accept') == true
	assert m.has_match('reject') == false
	assert m.has_match('include') == false
	assert m.has_match('exclude') == false
	assert m.get_all_matches('input') ? == [r'"\"hello\""', r'"\"this string has \\\"embedded\\\" double quotes\""']
}

fn test_escaped_bytes() ? {
	rplx := load_unittest_rpl_file(0) ?

	mut line := r'-- test value accepts "\x00", "\x01", "A", "!", "\x7a", "\x7f", "\0x7g", "\x80", "\xff", "\u2603", "\xE2\x98\x83"'

	// eprintln("line='$line'")
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	data := {
		'"\\x00"': 			[byte(0)]
		'"\\x01"': 			[byte(0x01)]
		'"A"': 				[byte(`A`)]
		'"!"': 				[byte(`!`)]
		'"\\x7a"': 			[byte(`z`)]
		'"\\x7f"':			[byte(0x7f)]
		'"\\0x7g"':			[]byte{}			// not a valid hex
		'"\\x80"':			[byte(0x80)]
		'"\\xff"':			[byte(0xff)]
		'"\\u2603"':		[byte(0xe2), 0x98, 0x83]
		'"\\xE2\\x98\\x83"':[byte(0xe2), 0x98, 0x83]
	}
	assert m.get_all_matches('input')? == data.keys()
	for k, v in data {
		x := ystrconv.interpolate_double_quoted_string(k, '') or { "xx" }
		y := x[1 .. x.len - 1].bytes()
		assert v == y
	}
}

fn test_rpl_file() ? {
	fpath := '$unittests.rpl_dir/../test/backref-rpl.rpl'
	mut f := read_file(fpath) ?
	f.run_tests(0) ?
	assert f.failure_count == 0
}

fn test_re_rpl() ? {
	fpath := '$unittests.rpl_dir/../rpl/re.rpl'
	mut f := read_file(fpath) ?
	f.run_tests(0)?
	assert f.failure_count == 0
}

fn skip_file(file string) bool {
	if os.file_name(os.dir(file)) == 'builtin' { return true }
	if file.ends_with("rpl_3_0_jdo.rpl") { return true}
	return false
}

fn test_orig_files() ? {
	files := os.walk_ext(unittests.rpl_dir, 'rpl')
	for fpath in files {
		if skip_file(fpath) == false {
			mut f := read_file(fpath) ?
			f.run_tests(0) ?
			assert f.failure_count == 0
		}
	}
}

fn test_orig_test_files() ? {
	files := os.walk_ext(unittests.rpl_dir, 'test')
	for fpath in files {
		mut f := read_file(fpath) ?
		f.run_tests(0) ?
		assert f.failure_count == 0
	}
}
/* */
