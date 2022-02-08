module rpl_3_0

import os
import rosie

fn test_multiplier() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: '"test"')?
	assert p.pattern("*")?.min == 1
	assert p.pattern("*")?.max == 1
	assert p.pattern_str("*") == '{"test"}'

	p = new_parser()?
	p.parse(data: '"test"*')?
	assert p.pattern("*")?.at(0)?.min == 0
	assert p.pattern("*")?.at(0)?.max == -1
	assert p.pattern_str("*") == '{"test"*}'

	p = new_parser()?
	p.parse(data: '"test"+')?
	assert p.pattern("*")?.at(0)?.min == 1
	assert p.pattern("*")?.at(0)?.max == -1
	assert p.pattern_str("*") == '{"test"+}'

	p = new_parser()?
	p.parse(data: '"test"?')?
	assert p.pattern("*")?.at(0)?.min == 0
	assert p.pattern("*")?.at(0)?.max == 1
	assert p.pattern_str("*") == '{"test"?}'

	p = new_parser()?
	p.parse(data: '"test"{2,4}')?
	assert p.pattern("*")?.at(0)?.min == 2
	assert p.pattern("*")?.at(0)?.max == 4
	assert p.pattern_str("*") == '{"test"{2,4}}'

	p = new_parser()?
	p.parse(data: '"test"{,4}')?
	assert p.pattern("*")?.at(0)?.min == 0
	assert p.pattern("*")?.at(0)?.max == 4
	assert p.pattern_str("*") == '{"test"{0,4}}'

	p = new_parser()?
	p.parse(data: '"test"{4,}')?
	assert p.pattern("*")?.at(0)?.min == 4
	assert p.pattern("*")?.at(0)?.max == -1
	assert p.pattern_str("*") == '{"test"{4,}}'

	p = new_parser(debug: 0)?
	p.parse(data: '"test"{4}')?
	assert p.pattern("*")?.at(0)?.min == 4
	assert p.pattern("*")?.at(0)?.max == 4
	assert p.pattern_str("*") == '{"test"{4,4}}'

	p = new_parser()?
	p.parse(data: '"test"{,}')?
	assert p.pattern("*")?.at(0)?.min == 0
	assert p.pattern("*")?.at(0)?.max == -1
	assert p.pattern_str("*") == '{"test"*}'
}

fn test_predicates() ? {
	mut p := new_parser()?
	p.parse(data: '>"test"')?
	assert p.pattern("*")?.at(0)?.predicate == .look_ahead
	assert p.pattern_str("*") == '{>"test"}'

	p = new_parser()?
	p.parse(data: '<"test"')?
	assert p.pattern("*")?.at(0)?.predicate == .look_behind
	assert p.pattern_str("*") == '{<"test"}'

	p = new_parser()?
	p.parse(data: '!"test"')?
	assert p.pattern("*")?.at(0)?.predicate == .negative_look_ahead
	assert p.pattern_str("*") == '{!"test"}'

	p = new_parser()?
	p.parse(data: '!>"test"')?
	assert p.pattern("*")?.at(0)?.predicate == .negative_look_ahead
	assert p.pattern_str("*") == '{!"test"}'

	p = new_parser()?
	p.parse(data: '!<"test"')?
	assert p.pattern("*")?.at(0)?.predicate == .negative_look_behind
	assert p.pattern_str("*") == '{!<"test"}'

	p = new_parser()?
	p.parse(data: '<!"test"')?
	assert p.pattern("*")?.at(0)?.predicate == .negative_look_ahead
	assert p.pattern_str("*") == '{!"test"}'

	p = new_parser()?
	p.parse(data: '>!"test"')?
	assert p.pattern("*")?.at(0)?.predicate == .negative_look_ahead
	assert p.pattern_str("*") == '{!"test"}'

	p = new_parser()?
	p.parse(data: '<>"test"')?
	assert p.pattern("*")?.at(0)?.predicate == .look_ahead
	assert p.pattern_str("*") == '{>"test"}'
}

fn test_choice() ? {
	mut p := new_parser()?
	p.parse(data: '"test" / "abc"')?
	assert p.pattern("*")?.repr() == '{"test" / "abc"}'

	p = new_parser()?
	p.parse(data: '"test"* / !"abc" / "1"')?
	assert p.pattern_str("*") == '{"test"* / !"abc" / "1"}'

	p = new_parser()?
	p.parse(data: '"test"* <"abc" / "1"')?
	assert p.pattern_str("*") == '{"test"* <"abc" / "1"}'	// rpl-3 has no implicit tokenization
}

fn test_sequence() ? {
	mut p := new_parser()?
	p.parse(data: '"test" "abc"')?
	assert p.pattern_str("*") == '{"test" "abc"}'

	p = new_parser()?
	p.parse(data: '"test"* !"abc" "1"')?
	assert p.pattern_str("*") == '{"test"* !"abc" "1"}'
}

fn test_parenthenses() ? {
	mut p := new_parser()?
	p.parse(data: '("test" "abc")')?
	assert p.pattern_str("*") == '{{"test" "abc"}}'
	assert p.pattern("*")?.elem is rosie.GroupPattern

	p = new_parser()?
	p.parse(data: '"a" ("test"* !"abc")? "1"')?
	assert p.pattern_str("*") == '{"a" {"test"* !"abc"}? "1"}'
}

fn test_braces() ? {
	mut p := new_parser()?
	p.parse(data: '("test" "abc")')?
	assert p.pattern_str("*") == '{{"test" "abc"}}'

	p = new_parser()?
	p.parse(data: '"a" ("test"* !"abc")? "1"')?
	assert p.pattern_str("*") == '{"a" {"test"* !"abc"}? "1"}'
}

fn test_parenthenses_and_braces() ? {
	mut p := new_parser()?
	p.parse(data: '("test") / ("abc")')?
	assert p.pattern_str("*") == '{{"test"} / {"abc"}}'

	p = new_parser()?
	p.parse(data: '("a" ("test"* !"abc")?) / "1"')?
	assert p.pattern_str("*") == '{{"a" {"test"* !"abc"}?} / "1"}'
}

fn test_quote_escaped() ? {
	// TODO: {["]["]}  Something an optimizer could reduce to '""'
	data := r'"\\\"" / "\\\"\\\"" / (["]["])   -- \" or \"\" or ""'
	assert data[0] == `"`
	assert data[1] == `\\`
	assert data[2] == `\\`
	assert data[3] == `\\`
	assert data[4] == `"`

	mut p := new_parser(debug: 0)?
	p.parse(data: data)?
	assert p.pattern_str("*") == r'{"\\"" / "\\"\\"" / {[(34)] [(34)]}}'
}

fn test_dot() ? {
	mut p := new_parser()?
	p.parse(data: '.')?
	assert p.pattern_str("*") == '{.}'
	assert p.pattern("*")?.at(0)?.elem is rosie.NamePattern

	p = new_parser()?
	p.parse(data: '.*')?
	assert p.pattern_str("*") == "{.*}"
	assert p.pattern("*")?.at(0)?.elem is rosie.NamePattern
	assert p.pattern("*")?.at(0)?.min == 0
	assert p.pattern("*")?.at(0)?.max == -1
}

fn test_issue_1() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: '>(("."? ([:space:] / $)) / ([:punct:] !"."))')?
	assert p.pattern_str("*") == r'{>{{"."? {[(9-13)(32)] / $}} / {[(32-47)(58-64)(91)(93-96)(123-126)] !"."}}}'
	assert p.pattern("*")?.at(0)?.predicate == .look_ahead
}

/*
RPL-3 parser can only import rpl-3 files.
fn test_parse_imports() ? {
	rosie := rosie.init_rosie()?
	f := os.join_path(rosie.home, "rpl", "all.rpl")
	eprintln("rpl file: $f ------------------------------------------")
	mut p := new_parser() or {
		return error("${err.msg}; file: $f")
	}

	p.parse(file: f) or {
		return error("${err.msg}; file: $f")
	}

	assert p.package().name == "all"
	assert "ts" in p.package().imports
	assert "date" in p.package().imports
	assert "time" in p.package().imports
	assert "net" in p.package().imports
	assert "num" in p.package().imports
	assert "id" in p.package().imports
	assert "word" in p.package().imports

	assert p.binding("special_char")?.name == "special_char"
	assert p.binding("ts.slashed_date")?.name == "slashed_date"
}
*/
fn test_parse_orig_rosie_rpl_files() ? {
	rplx_file := os.dir(@FILE) + "/../../../rpl"
	eprintln("rpl dir: $rplx_file")
	files := os.walk_ext(rplx_file, "rpl")
	for f in files {
		if os.file_name(os.dir(f)) != "builtin" {
			eprintln("file: $f")
			data := os.read_file(f)?
			mut p := new_parser() or {
				return error("${err.msg}; file: $f")
			}
			p.parse(data: data) or {
				return error("${err.msg}; file: $f")
			}
		}
	}
}
/* */