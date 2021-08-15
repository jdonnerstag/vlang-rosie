module inline_tests

import os
import rosie.runtime_v2 as rt

const rpl_dir = os.dir(@FILE) + "/../../../rpl"

fn test_load_unittest() ? {
	rplx := load_rpl_file(0)?
    mut line := '-- test mypat accepts "test"\n'
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.has_match("slocal") == false
    assert m.get_match_by("pat")? == "mypat"
    assert m.has_match("accept") == true
    assert m.has_match("reject") == false
    assert m.has_match("include") == false
    assert m.has_match("exclude") == false
    assert m.get_match_by("input")? == '"test"'
}

fn test_multiple_inputs() ? {
	rplx := load_rpl_file(0)?
    mut line := '-- test local mypat rejects "test", "abc"'
    mut m := rt.new_match(rplx, 99)
    assert m.vm_match(line) == true
    assert m.has_match("slocal") == true
    assert m.get_match_by("pat")? == "mypat"
    assert m.has_match("accept") == false
    assert m.has_match("reject") == true
    assert m.has_match("include") == false
    assert m.has_match("exclude") == false
    assert m.get_match_by("input")? == '"test"'
    assert m.get_all_match_by("unittest", "input")? == ['"test"', '"abc"']
}
/*
fn test_include() ? {
	rplx := load_rpl_file(0)?

    mut line := '-- test mypat includes abc "test"'
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    assert m.has_match("slocal") == true
    assert m.get_match_by("pat") == "mypat"
    assert m.has_match("accept") == false
    assert m.has_match("reject") == false
    assert m.has_match("include") == true
    assert m.has_match("exclude") == false
    assert m.get_match_by("input") == '"test"'
    assert m.get_match_by("include/pat") == '"test"'
}

/*
fn test_orig_files() ? {
	fpath := "${rpl_dir}/num.rpl"
	mut f := read_file(fpath)?
	// eprintln(f)
	f.run_tests()?
	eprintln(f.results)
	assert false
}
/*
fn test_orig_files() ? {
	eprintln("rpl dir: $rpl_dir")
	files := os.walk_ext(rpl_dir, "rpl")
	for f in files {
		eprintln("file: $f")
	}
}
*/