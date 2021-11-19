module core_0

import os
import rosie

fn test_multiplier() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: '"test"')?
	assert p.pattern("*")?.min == 1
	assert p.pattern("*")?.max == 1
	assert p.pattern_str("*") == '"test"'

	p = new_parser(debug: 0)?
	p.parse(data: '"test"*')?
	assert p.pattern("*")?.min == 0
	assert p.pattern("*")?.max == -1
	assert p.pattern_str("*") == '"test"*'

	p = new_parser(debug: 0)?
	p.parse(data: '"test"+')?
	assert p.pattern("*")?.min == 1
	assert p.pattern("*")?.max == -1
	assert p.pattern_str("*") == '"test"+'

	p = new_parser(debug: 0)?
	p.parse(data: '"test"?')?
	assert p.pattern("*")?.min == 0
	assert p.pattern("*")?.max == 1
	assert p.pattern_str("*") == '"test"?'

	p = new_parser(debug: 0)?
	p.parse(data: '"test"{2,4}')?
	assert p.pattern("*")?.min == 2
	assert p.pattern("*")?.max == 4
	assert p.pattern_str("*") == '"test"{2,4}'

	p = new_parser(debug: 0)?
	p.parse(data: '"test"{,4}')?
	assert p.pattern("*")?.min == 0
	assert p.pattern("*")?.max == 4
	assert p.pattern_str("*") == '"test"{0,4}'

	p = new_parser(debug: 0)?
	p.parse(data: '"test"{4,}')?
	assert p.pattern("*")?.min == 4
	assert p.pattern("*")?.max == -1
	assert p.pattern_str("*") == '"test"{4,}'

	p = new_parser(debug: 0)?
	p.parse(data: '"test"{4}')?
	assert p.pattern("*")?.min == 4
	assert p.pattern("*")?.max == 4
	assert p.pattern_str("*") == '"test"{4,4}'

	p = new_parser(debug: 0)?
	p.parse(data: '"test"{,}')?
	assert p.pattern("*")?.min == 0
	assert p.pattern("*")?.max == -1
	assert p.pattern_str("*") == '"test"*'
}

fn test_predicates() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: '>"test"')?
	assert p.pattern("*")?.predicate == .look_ahead
	assert p.pattern_str("*") == '>"test"'

	p = new_parser(debug: 0)?
	p.parse(data: '<"test"')?
	assert p.pattern("*")?.predicate == .look_behind
	assert p.pattern_str("*") == '<"test"'

	p = new_parser(debug: 0)?
	p.parse(data: '!"test"')?
	assert p.pattern("*")?.predicate == .negative_look_ahead
	assert p.pattern_str("*") == '!"test"'

	p = new_parser(debug: 0)?
	p.parse(data: '!>"test"')?
	assert p.pattern("*")?.predicate == .negative_look_ahead
	assert p.pattern_str("*") == '!"test"'

	p = new_parser(debug: 0)?
	p.parse(data: '!<"test"')?
	assert p.pattern("*")?.predicate == .negative_look_behind
	assert p.pattern_str("*") == '!<"test"'

	p = new_parser(debug: 0)?
	p.parse(data: '<!"test"')?
	assert p.pattern("*")?.predicate == .negative_look_ahead
	assert p.pattern_str("*") == '!"test"'

	p = new_parser(debug: 0)?
	p.parse(data: '>!"test"')?
	assert p.pattern("*")?.predicate == .negative_look_ahead
	assert p.pattern_str("*") == '!"test"'

	p = new_parser(debug: 0)?
	p.parse(data: '<>"test"')?
	assert p.pattern("*")?.predicate == .look_ahead
	assert p.pattern_str("*") == '>"test"'
}

fn test_choice() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: '"test" / "abc"')?
	assert p.pattern("*")?.repr() == '["test" "abc"]'
	assert p.pattern("*")?.elem is rosie.DisjunctionPattern
	assert p.pattern("*")?.at(0)?.text()? == "test"
	assert p.pattern("*")?.at(1)?.text()? == "abc"

	p = new_parser(debug: 0)?
	p.parse(data: '"test"* / !"abc" / "1"')?
	assert p.pattern_str("*") == '["test"* !"abc" "1"]'
	assert p.pattern("*")?.at(0)?.text()? == "test"
	assert p.pattern("*")?.at(0)?.min == 0
	assert p.pattern("*")?.at(0)?.max == -1
	assert p.pattern("*")?.at(1)?.text()? == "abc"
	assert p.pattern("*")?.at(1)?.predicate == .negative_look_ahead
	assert p.pattern("*")?.at(2)?.text()? == "1"

	p = new_parser(debug: 0)?
	p.parse(data: '"test"* <"abc" / "1"')?
	assert p.pattern_str("*") == 'tok:{"test"* [<"abc" "1"]}'
	assert p.pattern("*")?.at(0)?.text()? == "test"
	assert p.pattern("*")?.at(0)?.min == 0
	assert p.pattern("*")?.at(0)?.max == -1
	assert p.pattern("*")?.at(1)?.at(0)?.text()? == "abc"
	assert p.pattern("*")?.at(1)?.at(0)?.predicate == .look_behind
	assert p.pattern("*")?.at(1)?.at(1)?.text()? == "1"
}

fn test_sequence() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: '"test" "abc"')?
	assert p.pattern_str("*") == 'tok:{"test" "abc"}'
	assert p.pattern("*")?.at(0)?.text()? == "test"
	assert p.pattern("*")?.at(1)?.text()? == "abc"

	p = new_parser(debug: 0)?
	p.parse(data: '"test"* !"abc" "1"')?
	assert p.pattern_str("*") == 'tok:{"test"* !"abc" "1"}'
	assert p.pattern("*")?.at(0)?.text()? == "test"
	assert p.pattern("*")?.at(0)?.min == 0
	assert p.pattern("*")?.at(0)?.max == -1
	assert p.pattern("*")?.at(1)?.text()? == "abc"
	assert p.pattern("*")?.at(1)?.min == 1
	assert p.pattern("*")?.at(1)?.max == 1
	assert p.pattern("*")?.at(2)?.text()? == "1"
	assert p.pattern("*")?.at(2)?.min == 1
	assert p.pattern("*")?.at(2)?.max == 1
}

fn test_parenthenses() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: '("test" "abc")')?
	assert p.pattern_str("*") == 'tok:{"test" "abc"}'
	assert p.pattern("*")?.elem is rosie.MacroPattern
	assert p.pattern("*")?.at(0)?.text()? == "test"
	assert p.pattern("*")?.at(1)?.text()? == "abc"

	p = new_parser(debug: 0)?
	p.parse(data: '"a" ("test"* !"abc")? "1"')?
	assert p.pattern_str("*") == 'tok:{"a" tok:{"test"* !"abc"}? "1"}'
	assert p.pattern("*")?.at(0)?.text()? == "a"
	assert p.pattern("*")?.at(1)?.elem is rosie.MacroPattern
	assert p.pattern("*")?.at(1)?.at(0)?.text()? == "test"
	assert p.pattern("*")?.at(1)?.at(0)?.min == 0
	assert p.pattern("*")?.at(1)?.at(0)?.max == -1
	assert p.pattern("*")?.at(1)?.at(1)?.text()? == "abc"
	assert p.pattern("*")?.at(1)?.at(1)?.predicate == .negative_look_ahead
	assert p.pattern("*")?.at(2)?.text()? == "1"
}

fn test_braces() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: '{"test" "abc"}')?
	assert p.pattern_str("*") == '{"test" "abc"}'
	assert p.pattern("*")?.elem is rosie.GroupPattern
	assert (p.pattern("*")?.elem as rosie.GroupPattern).word_boundary == false	// This is the default for sequences within the group
	assert p.pattern("*")?.at(0)?.text()? == "test"
	assert p.pattern("*")?.at(1)?.text()? == "abc"

	p = new_parser(debug: 0)?
	p.parse(data: '"a" {"test"* !"abc"}? "1"')?
	assert p.pattern_str("*") == 'tok:{"a" {"test"* !"abc"}? "1"}'
	assert p.pattern("*")?.elem is rosie.MacroPattern
	assert p.pattern("*")?.at(0)?.text()? == "a"
	assert p.pattern("*")?.at(1)?.elem is rosie.GroupPattern
	assert p.pattern("*")?.at(1)?.at(0)?.text()? == "test"
	assert p.pattern("*")?.at(1)?.at(0)?.min == 0
	assert p.pattern("*")?.at(1)?.at(0)?.max == -1
	assert p.pattern("*")?.at(1)?.at(1)?.text()? == "abc"
	assert p.pattern("*")?.at(1)?.at(1)?.predicate == .negative_look_ahead
	assert p.pattern("*")?.at(1)?.min == 0
	assert p.pattern("*")?.at(1)?.max == 1
	assert p.pattern("*")?.at(2)?.text()? == "1"
}

fn test_parenthenses_and_braces() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: '("test") / {"abc"}')?
	assert p.pattern_str("*") == '[tok:{"test"} {"abc"}]'
	assert p.pattern("*")?.elem is rosie.DisjunctionPattern
	assert p.pattern("*")?.at(0)?.elem is rosie.MacroPattern
	assert p.pattern("*")?.at(0)?.at(0)?.text()? == "test"
	assert p.pattern("*")?.at(1)?.elem is rosie.GroupPattern
	assert p.pattern("*")?.at(1)?.at(0)?.text()? == "abc"

	p = new_parser(debug: 0)?
	p.parse(data: '("a" {"test"* !"abc"}?) / "1"')?
	assert p.pattern_str("*") == '[tok:{"a" {"test"* !"abc"}?} "1"]'
	assert p.pattern("*")?.elem is rosie.DisjunctionPattern
	assert p.pattern("*")?.at(0)?.elem is rosie.MacroPattern
	assert p.pattern("*")?.at(1)?.text()? == "1"

	assert p.pattern("*")?.at(0)?.at(0)?.text()? == "a"
	assert p.pattern("*")?.at(0)?.at(1)?.elem is rosie.GroupPattern
	assert p.pattern("*")?.at(0)?.at(1)?.min == 0
	assert p.pattern("*")?.at(0)?.at(1)?.max == 1

	assert p.pattern("*")?.at(0)?.at(1)?.at(0)?.text()? == "test"
	assert p.pattern("*")?.at(0)?.at(1)?.at(0)?.min == 0
	assert p.pattern("*")?.at(0)?.at(1)?.at(0)?.max == -1

	assert p.pattern("*")?.at(0)?.at(1)?.at(1)?.text()? == "abc"
}

fn test_quote_escaped() ? {
	// TODO: {["]["]}  Something an optimizer could reduce to '""'
	data := r'"\\\"" / "\\\"\\\"" / {["]["]}   -- \" or \"\" or ""'
	assert data[0] == `"`
	assert data[1] == `\\`
	assert data[2] == `\\`
	assert data[3] == `\\`
	assert data[4] == `"`

	mut p := new_parser(debug: 0)?
	p.parse(data: data)?
	assert p.pattern_str("*") == r'["\"" "\"\"" {[(34)] [(34)]}]'	// TODO repr() does not yet escape
	assert p.pattern("*")?.elem is rosie.DisjunctionPattern
	assert p.pattern("*")?.at(0)?.text()? == r'\"'
	assert p.pattern("*")?.at(1)?.text()? == r'\"\"'
	assert p.pattern("*")?.at(2)?.elem is rosie.GroupPattern
}

fn test_dot() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: '.')?
	assert p.pattern_str("*") == '.'
	assert p.pattern("*")?.elem is rosie.NamePattern

	p = new_parser(debug: 0)?
	p.parse(data: '.*')?
	assert p.pattern_str("*") == ".*"
	assert p.pattern("*")?.elem is rosie.NamePattern
	assert p.pattern("*")?.min == 0
	assert p.pattern("*")?.max == -1
}

fn test_issue_1() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: '>{{"."? [[:space:] $]} / [[:punct:] & !"."]}')?
	assert p.pattern_str("*") == r'>{[{"."? [[(9-13)(32)] $]} [{[(32-47)(58-64)(91)(93-96)(123-126)] !"."}]]}'
	assert p.pattern("*")?.predicate == .look_ahead
}

fn test_parse_imports() ? {
	rosie := rosie.init_rosie()?
	f := os.join_path(rosie.home, "rpl", "all.rpl")
	eprintln("rpl file: $f ------------------------------------------")
	mut p := new_parser(debug: 0) or {
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

fn test_parse_orig_rosie_rpl_files() ? {
	rplx_file := os.dir(@FILE) + "/../../../rpl"
	eprintln("rpl dir: $rplx_file")
	files := os.walk_ext(rplx_file, "rpl")
	for f in files {
		if os.file_name(os.dir(f)) != "builtin" {
			eprintln("file: $f")
			mut p := new_parser(debug: 0) or {
				return error("${err.msg}; file: $f")
			}
			p.parse(file: f) or {
				return error("${err.msg}; file: $f")
			}
		}
	}
}
