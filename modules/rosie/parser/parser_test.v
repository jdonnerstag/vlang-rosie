module parser

import os

fn test_multiplier() ? {
	mut p := new_parser(data: '"test"', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.min == 1
	assert p.pattern("*")?.max == 1
	assert p.pattern_str("*") == '"test"'

	p = new_parser(data: '"test"*', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.min == 0
	assert p.pattern("*")?.max == -1
	assert p.pattern_str("*") == '"test"*'

	p = new_parser(data: '"test"+', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.min == 1
	assert p.pattern("*")?.max == -1
	assert p.pattern_str("*") == '"test"+'

	p = new_parser(data: '"test"?', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.min == 0
	assert p.pattern("*")?.max == 1
	assert p.pattern_str("*") == '"test"?'

	p = new_parser(data: '"test"{2,4}', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.min == 2
	assert p.pattern("*")?.max == 4
	assert p.pattern_str("*") == '"test"{2,4}'

	p = new_parser(data: '"test"{,4}', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.min == 0
	assert p.pattern("*")?.max == 4
	assert p.pattern_str("*") == '"test"{0,4}'

	p = new_parser(data: '"test"{4,}', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.min == 4
	assert p.pattern("*")?.max == -1
	assert p.pattern_str("*") == '"test"{4,}'

	p = new_parser(data: '"test"{,}', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.min == 0
	assert p.pattern("*")?.max == -1
	assert p.pattern_str("*") == '"test"*'
}

fn test_predicates() ? {
	mut p := new_parser(data: '>"test"', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.predicate == .look_ahead
	assert p.pattern_str("*") == '>"test"'

	p = new_parser(data: '<"test"', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.predicate == .look_behind
	assert p.pattern_str("*") == '<"test"'

	p = new_parser(data: '!"test"', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.predicate == .negative_look_ahead
	assert p.pattern_str("*") == '!"test"'

	p = new_parser(data: '!>"test"', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.predicate == .negative_look_ahead
	assert p.pattern_str("*") == '!"test"'

	p = new_parser(data: '!<"test"', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.predicate == .negative_look_behind
	assert p.pattern_str("*") == '!<"test"'

	p = new_parser(data: '<!"test"', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.predicate == .negative_look_ahead
	assert p.pattern_str("*") == '!"test"'

	p = new_parser(data: '>!"test"', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.predicate == .negative_look_ahead
	assert p.pattern_str("*") == '!"test"'

	p = new_parser(data: '<>"test"', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.predicate == .look_ahead
	assert p.pattern_str("*") == '>"test"'
}

fn test_choice() ? {
	mut p := new_parser(data: '"test" / "abc"', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.at(0)?.text()? == "test"
	assert p.pattern("*")?.at(0)?.operator == .choice
	assert p.pattern("*")?.at(1)?.text()? == "abc"
	assert p.pattern_str("*") == '("test" / "abc")'
	assert p.pattern("*")?.at(1)?.operator == .sequence
	assert p.pattern("*")?.at(1)?.word_boundary == true

	p = new_parser(data: '"test"* / !"abc" / "1"', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.at(0)?.text()? == "test"
	assert p.pattern("*")?.at(0)?.min == 0
	assert p.pattern("*")?.at(0)?.max == -1
	assert p.pattern("*")?.at(0)?.operator == .choice
	assert p.pattern("*")?.at(1)?.text()? == "abc"
	assert p.pattern("*")?.at(1)?.predicate == .negative_look_ahead
	assert p.pattern("*")?.at(1)?.operator == .choice
	assert p.pattern("*")?.at(2)?.text()? == "1"
	assert p.pattern_str("*") == '("test"* / !"abc" / "1")'

	p = new_parser(data: '"test"* <"abc" / "1"', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.at(0)?.text()? == "test"
	assert p.pattern("*")?.at(0)?.min == 0
	assert p.pattern("*")?.at(0)?.max == -1
	assert p.pattern("*")?.at(0)?.operator == .sequence
	assert p.pattern("*")?.at(1)?.text()? == "abc"
	assert p.pattern("*")?.at(1)?.predicate == .look_behind
	assert p.pattern("*")?.at(1)?.operator == .choice
	assert p.pattern("*")?.at(2)?.text()? == "1"
	assert p.pattern_str("*") == '("test"* <"abc" / "1")'
}

fn test_sequence() ? {
	mut p := new_parser(data: '"test" "abc"', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.at(0)?.text()? == "test"
	assert p.pattern("*")?.at(0)?.operator == .sequence
	assert p.pattern("*")?.at(0)?.word_boundary == true
	assert p.pattern("*")?.at(1)?.text()? == "abc"
	assert p.pattern_str("*") == '("test" "abc")'

	p = new_parser(data: '"test"* !"abc" "1"', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.at(0)?.text()? == "test"
	assert p.pattern("*")?.at(0)?.operator == .sequence
	assert p.pattern("*")?.at(0)?.min == 0
	assert p.pattern("*")?.at(0)?.max == -1
	assert p.pattern("*")?.at(0)?.word_boundary == true
	assert p.pattern("*")?.at(1)?.text()? == "abc"
	assert p.pattern("*")?.at(1)?.operator == .sequence
	assert p.pattern("*")?.at(1)?.min == 1
	assert p.pattern("*")?.at(1)?.max == 1
	assert p.pattern("*")?.at(1)?.word_boundary == true
	assert p.pattern("*")?.at(2)?.text()? == "1"
	assert p.pattern("*")?.at(2)?.min == 1
	assert p.pattern("*")?.at(2)?.max == 1
	assert p.pattern_str("*") == '("test"* !"abc" "1")'
}

fn test_parenthenses() ? {
	mut p := new_parser(data: '("test" "abc")', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.elem is GroupPattern
	assert p.pattern("*")?.at(0)?.text()? == "test"
	assert p.pattern("*")?.at(0)?.word_boundary == true
	assert p.pattern("*")?.at(1)?.text()? == "abc"
	assert p.pattern_str("*") == '("test" "abc")'

	p = new_parser(data: '"a" ("test"* !"abc")? "1"', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.at(0)?.text()? == "a"
	assert p.pattern("*")?.at(0)?.word_boundary == true
	assert p.pattern("*")?.at(1)?.elem is GroupPattern
	assert p.pattern("*")?.at(1)?.at(0)?.text()? == "test"
	assert p.pattern("*")?.at(1)?.at(0)?.min == 0
	assert p.pattern("*")?.at(1)?.at(0)?.max == -1
	assert p.pattern("*")?.at(1)?.at(0)?.word_boundary == true
	assert p.pattern("*")?.at(1)?.at(1)?.text()? == "abc"
	assert p.pattern("*")?.at(1)?.at(1)?.predicate == .negative_look_ahead
	assert p.pattern("*")?.at(1)?.at(1)?.word_boundary == true
	assert p.pattern("*")?.at(1)?.min == 0
	assert p.pattern("*")?.at(1)?.max == 1
	assert p.pattern("*")?.at(1)?.word_boundary == true
	assert p.pattern("*")?.at(2)?.text()? == "1"
	assert p.pattern_str("*") == '("a" ("test"* !"abc")? "1")'
}

fn test_braces() ? {
	mut p := new_parser(data: '{"test" "abc"}', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.word_boundary == true	// This will be applied to the next pattern, the one following the braces
	assert p.pattern("*")?.elem is GroupPattern
	assert (p.pattern("*")?.elem as GroupPattern).word_boundary == false	// This is the default for sequences within the group
	assert p.pattern("*")?.at(0)?.text()? == "test"
	assert p.pattern("*")?.at(0)?.word_boundary == false
	assert p.pattern("*")?.at(1)?.text()? == "abc"
	assert p.pattern("*")?.at(1)?.word_boundary == false
	assert p.pattern_str("*") == '{"test" "abc"}'

	p = new_parser(data: '"a" {"test"* !"abc"}? "1"', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.elem is GroupPattern
	assert p.pattern("*")?.word_boundary == true
	assert p.pattern("*")?.at(0)?.text()? == "a"
	assert p.pattern("*")?.at(0)?.word_boundary == true
	assert p.pattern("*")?.at(1)?.elem is GroupPattern
	assert p.pattern("*")?.at(1)?.word_boundary == true
	assert p.pattern("*")?.at(1)?.at(0)?.text()? == "test"
	assert p.pattern("*")?.at(1)?.at(0)?.word_boundary == false
	assert p.pattern("*")?.at(1)?.at(0)?.min == 0
	assert p.pattern("*")?.at(1)?.at(0)?.max == -1
	assert p.pattern("*")?.at(1)?.at(1)?.text()? == "abc"
	assert p.pattern("*")?.at(1)?.at(1)?.predicate == .negative_look_ahead
	assert p.pattern("*")?.at(1)?.at(1)?.word_boundary == false
	assert p.pattern("*")?.at(1)?.min == 0
	assert p.pattern("*")?.at(1)?.max == 1
	assert p.pattern("*")?.at(2)?.text()? == "1"
	assert p.pattern_str("*") == '("a" {"test"* !"abc"}? "1")'
}

fn test_parenthenses_and_braces() ? {
	mut p := new_parser(data: '("test") / {"abc"}', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.elem is GroupPattern
	assert p.pattern("*")?.word_boundary == true
	assert p.pattern("*")?.at(0)?.elem is GroupPattern
	assert p.pattern("*")?.at(0)?.word_boundary == false	// because it is a choice
	assert p.pattern("*")?.at(0)?.operator == .choice
	assert p.pattern("*")?.at(0)?.at(0)?.text()? == "test"
	assert p.pattern("*")?.at(1)?.elem is GroupPattern
	assert (p.pattern("*")?.at(1)?.elem as GroupPattern).word_boundary == false
	assert p.pattern("*")?.at(1)?.at(0)?.text()? == "abc"
	assert p.pattern_str("*") == '(("test") / {"abc"})'

	p = new_parser(data: '("a" {"test"* !"abc"}?) / "1"', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.at(0)?.elem is GroupPattern
	assert p.pattern("*")?.at(0)?.operator == .choice
	assert p.pattern("*")?.at(1)?.text()? == "1"

	assert p.pattern("*")?.at(0)?.at(0)?.text()? == "a"
	assert p.pattern("*")?.at(0)?.at(1)?.elem is GroupPattern
	assert (p.pattern("*")?.at(0)?.at(1)?.elem as GroupPattern).word_boundary == false
	assert p.pattern("*")?.at(0)?.at(1)?.min == 0
	assert p.pattern("*")?.at(0)?.at(1)?.max == 1

	assert p.pattern("*")?.at(0)?.at(1)?.at(0)?.text()? == "test"
	assert p.pattern("*")?.at(0)?.at(1)?.at(0)?.min == 0
	assert p.pattern("*")?.at(0)?.at(1)?.at(0)?.max == -1
	assert p.pattern("*")?.at(0)?.at(1)?.at(0)?.word_boundary == false
	assert p.pattern("*")?.at(0)?.at(1)?.at(0)?.operator == .sequence

	assert p.pattern("*")?.at(0)?.at(1)?.at(1)?.text()? == "abc"
	assert p.pattern_str("*") == '(("a" {"test"* !"abc"}?) / "1")'
}

fn test_quote_escaped() ? {
	// TODO: {["]["]}  Something an optimizer could reduce to '""'
	data := r'"\\\"" / "\\\"\\\"" / {["]["]}   -- \" or \"\" or ""'
	assert data[0] == `"`
	assert data[1] == `\\`
	assert data[2] == `\\`
	assert data[3] == `\\`
	assert data[4] == `"`

	mut p := new_parser(data: data, debug: 0)?
	p.parse_binding()?

	assert p.pattern("*")?.elem is GroupPattern
	assert p.pattern("*")?.at(0)?.text()? == r'\"'
	assert p.pattern("*")?.at(0)?.operator == .choice
	assert p.pattern("*")?.at(1)?.text()? == r'\"\"'
	assert p.pattern("*")?.at(1)?.operator == .choice
	assert p.pattern("*")?.at(2)?.elem is GroupPattern
	assert p.pattern_str("*") == r'("\"" / "\"\"" / {[(34)] [(34)]})'	// TODO repr() does not yet escape
}

fn test_dot() ? {
	mut p := new_parser(data: '.', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.elem is NamePattern
	assert p.pattern("*")?.word_boundary == true
	assert p.pattern_str("*") == '.'

	p = new_parser(data: '.*', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.elem is NamePattern
	assert p.pattern("*")?.min == 0
	assert p.pattern("*")?.max == -1
	assert p.pattern_str("*") == ".*"
}

fn test_issue_1() ? {
	mut p := new_parser(data: '>{{"."? [[:space:] $]} / [[:punct:] & !"."]}', debug: 0)?
	p.parse_binding()?
	assert p.pattern("*")?.predicate == .look_ahead
	assert p.pattern_str("*") == r'>{{"."? [[(9-13)(32)] $]} / [(32-45)(47)(58-64)(91)(93-96)(123-126)]}'
}

fn test_parse_imports() ? {
	f := r"C:\source_code\vlang\vlang-rosie\modules\rosie\parser/../../../rpl\all.rpl"
	eprintln("rpl file: $f ------------------------------------------")
	mut p := new_parser(fpath: f, debug: 0) or {
		return error("${err.msg}; file: $f")
	}
	p.parse() or {
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
	//assert p.package().get("ts.date.date.us_slashed")?.name == "us_slashed"
	//assert p.package().get("date.year")?.name == "year"
}

fn test_parse_orig_rosie_rpl_files() ? {
    rplx_file := os.dir(@FILE) + "/../../../rpl"
	eprintln("rpl dir: $rplx_file")
	files := os.walk_ext(rplx_file, "rpl")
	for f in files {
		if os.file_name(os.dir(f)) != "builtin" {
			eprintln("file: $f")
			data := os.read_file(f)?
			mut p := new_parser(data: data, debug: 0) or {
				return error("${err.msg}; file: $f")
			}
			p.parse() or {
				return error("${err.msg}; file: $f")
			}
		}
	}
}
