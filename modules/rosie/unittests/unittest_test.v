module unittests

import os
import rosie.runtime_v2 as rt

const rpl_dir = os.dir(@FILE) + '/../../../rpl'

fn test_load_unittest() ? {
	rplx := load_unittest_rpl_file(0) ?
	mut line := '-- test mypat accepts "test"'
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.has_match('slocal') == false
	assert m.get_match_by('pat') ? == 'mypat'
	assert m.has_match('accept') == true
	assert m.has_match('reject') == false
	assert m.has_match('include') == false
	assert m.has_match('exclude') == false
	assert m.get_match_by('input') ? == '"test"'
}

fn test_multiple_inputs() ? {
	rplx := load_unittest_rpl_file(0) ?
	mut line := '-- test local mypat rejects "test", "abc"'
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.has_match('slocal') == true
	assert m.get_match_by('pat') ? == 'mypat'
	assert m.has_match('accept') == false
	assert m.has_match('reject') == true
	assert m.has_match('include') == false
	assert m.has_match('exclude') == false
	assert m.get_match_by('input') ? == '"test"'
	assert m.get_all_match_by('input') ? == ['"test"', '"abc"']
}

fn test_include() ? {
	rplx := load_unittest_rpl_file(0) ?

	mut line := '-- test mypat includes abc "test"'
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.has_match('slocal') == false
	assert m.get_match_by('pat') ? == 'mypat'
	assert m.has_match('accept') == false
	assert m.has_match('reject') == false
	assert m.has_match('include') == true
	assert m.has_match('exclude') == false
	assert m.get_match_by('input') ? == '"test"'
	assert m.get_match_by('include', 'subpat') ? == 'abc'
}

fn test_include_dotted() ? {
	rplx := load_unittest_rpl_file(0) ?

	mut line := '-- test mypat includes abc.def "test"'
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.has_match('slocal') == false
	assert m.get_match_by('pat') ? == 'mypat'
	assert m.has_match('accept') == false
	assert m.has_match('reject') == false
	assert m.has_match('include') == true
	assert m.has_match('exclude') == false
	assert m.get_match_by('input') ? == '"test"'
	assert m.get_match_by('include', 'subpat') ? == 'abc.def'
}

fn test_escaped_quoted_string() ? {
	rplx := load_unittest_rpl_file(0) ?

	mut line := r'-- test value accepts "\"hello\"", "\"this string has \\\"embedded\\\" double quotes\""'

	// eprintln("line='$line'")
	mut m := rt.new_match(rplx: rplx, debug: 0)
	assert m.vm_match(line)? == true
	assert m.has_match('slocal') == false
	assert m.get_match_by('pat') ? == 'value'
	assert m.has_match('accept') == true
	assert m.has_match('reject') == false
	assert m.has_match('include') == false
	assert m.has_match('exclude') == false
	assert m.get_all_match_by('input') ? == [r'"\"hello\""',
		r'"\"this string has \\\"embedded\\\" double quotes\""']
}

fn test_rpl_file() ? {
	fpath := '$unittests.rpl_dir/../test/backref-rpl.rpl'
	mut f := read_file(fpath) ?
	f.run_tests(0) ?
	assert f.failure_count == 0
}

fn test_orig_files() ? {
	files := os.walk_ext(unittests.rpl_dir, 'rpl')
	for fpath in files {
		if os.file_name(os.dir(fpath)) != 'builtin' {
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

//
