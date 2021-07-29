module parser

import os

fn test_multiplier() ? {
	mut p := new_parser(data: '"test"', debug: 0)?
	p.parse_binding()?
	assert p.binding("*")?.at(0)?.min == 1
	assert p.binding("*")?.at(0)?.max == 1
	assert p.binding_str("*") == '("test")'

	p = new_parser(data: '"test"*', debug: 0)?
	p.parse_binding()?
	assert p.binding("*")?.at(0)?.min == 0
	assert p.binding("*")?.at(0)?.max == -1
	assert p.binding_str("*") == '("test"*)'

	p = new_parser(data: '"test"+', debug: 0)?
	p.parse_binding()?
	assert p.binding("*")?.at(0)?.min == 1
	assert p.binding("*")?.at(0)?.max == -1
	assert p.binding_str("*") == '("test"+)'

	p = new_parser(data: '"test"?', debug: 0)?
	p.parse_binding()?
	assert p.binding("*")?.at(0)?.min == 0
	assert p.binding("*")?.at(0)?.max == 1
	assert p.binding_str("*") == '("test"?)'

	p = new_parser(data: '"test"{2,4}', debug: 0)?
	p.parse_binding()?
	assert p.binding("*")?.at(0)?.min == 2
	assert p.binding("*")?.at(0)?.max == 4
	assert p.binding_str("*") == '("test"{2,4})'

	p = new_parser(data: '"test"{,4}', debug: 0)?
	p.parse_binding()?
	assert p.binding("*")?.at(0)?.min == 0
	assert p.binding("*")?.at(0)?.max == 4
	assert p.binding_str("*") == '("test"{0,4})'

	p = new_parser(data: '"test"{4,}', debug: 0)?
	p.parse_binding()?
	assert p.binding("*")?.at(0)?.min == 4
	assert p.binding("*")?.at(0)?.max == -1
	assert p.binding_str("*") == '("test"{4,})'

	p = new_parser(data: '"test"{,}', debug: 0)?
	p.parse_binding()?
	assert p.binding("*")?.at(0)?.min == 0
	assert p.binding("*")?.at(0)?.max == -1
	assert p.binding_str("*") == '("test"*)'
}

// TODO need tests for predicates

fn test_choice() ? {
	mut p := new_parser(data: '"test" / "abc"', debug: 0)?
	p.parse_binding()?
	assert p.binding("*")?.at(0)?.text()? == "test"
	assert p.binding("*")?.at(0)?.operator == .choice
	assert p.binding("*")?.at(1)?.text()? == "abc"
	assert p.binding_str("*") == '("test" / "abc")'

	p = new_parser(data: '"test"* / !"abc" / "1"', debug: 0)?
	p.parse_binding()?
	assert p.binding("*")?.at(0)?.text()? == "test"
	assert p.binding("*")?.at(0)?.min == 0
	assert p.binding("*")?.at(0)?.max == -1
	assert p.binding("*")?.at(0)?.operator == .choice
	assert p.binding("*")?.at(1)?.text()? == "abc"
	assert p.binding("*")?.at(1)?.predicate == .negative_look_ahead
	assert p.binding("*")?.at(1)?.operator == .choice
	assert p.binding("*")?.at(2)?.text()? == "1"
	assert p.binding_str("*") == '("test"* / !>"abc" / "1")'

	p = new_parser(data: '"test"* <"abc" / "1"', debug: 0)?
	p.parse_binding()?
	assert p.binding("*")?.at(0)?.text()? == "test"
	assert p.binding("*")?.at(0)?.min == 0
	assert p.binding("*")?.at(0)?.max == -1
	assert p.binding("*")?.at(0)?.operator == .sequence
	assert p.binding("*")?.at(1)?.text()? == "abc"
	assert p.binding("*")?.at(1)?.predicate == .look_behind
	assert p.binding("*")?.at(1)?.operator == .choice
	assert p.binding("*")?.at(2)?.text()? == "1"
	assert p.binding_str("*") == '("test"* <"abc" / "1")'
}

fn test_sequence() ? {
	mut p := new_parser(data: '"test" "abc"', debug: 0)?
	p.parse_binding()?
	assert p.binding("*")?.at(0)?.text()? == "test"
	assert p.binding("*")?.at(0)?.operator == .sequence
	assert p.binding("*")?.at(1)?.text()? == "abc"
	assert p.binding_str("*") == '("test" "abc")'

	p = new_parser(data: '"test"* !"abc" "1"', debug: 0)?
	p.parse_binding()?
	assert p.binding("*")?.at(0)?.text()? == "test"
	assert p.binding("*")?.at(0)?.operator == .sequence
	assert p.binding("*")?.at(0)?.min == 0
	assert p.binding("*")?.at(0)?.max == -1
	assert p.binding("*")?.at(1)?.text()? == "abc"
	assert p.binding("*")?.at(1)?.operator == .sequence
	assert p.binding("*")?.at(1)?.min == 1
	assert p.binding("*")?.at(1)?.max == 1
	assert p.binding("*")?.at(2)?.text()? == "1"
	assert p.binding("*")?.at(2)?.min == 1
	assert p.binding("*")?.at(2)?.max == 1
	assert p.binding_str("*") == '("test"* !>"abc" "1")'
}

fn test_parenthenses() ? {
	mut p := new_parser(data: '("test" "abc")', debug: 0)?
	p.parse_binding()?
	assert p.binding("*")?.at(0)?.elem is GroupPattern
	assert p.binding("*")?.at(0)?.at(0)?.text()? == "test"
	assert p.binding("*")?.at(0)?.at(1)?.text()? == "abc"
	assert p.binding_str("*") == '(("test" "abc"))'

	p = new_parser(data: '"a" ("test"* !"abc")? "1"', debug: 0)?
	p.parse_binding()?
	assert p.binding("*")?.at(0)?.text()? == "a"
	assert p.binding("*")?.at(1)?.elem is GroupPattern
	assert p.binding("*")?.at(1)?.at(0)?.text()? == "test"
	assert p.binding("*")?.at(1)?.at(0)?.min == 0
	assert p.binding("*")?.at(1)?.at(0)?.max == -1
	assert p.binding("*")?.at(1)?.at(1)?.text()? == "abc"
	assert p.binding("*")?.at(1)?.at(1)?.predicate == .negative_look_ahead
	assert p.binding("*")?.at(1)?.min == 0
	assert p.binding("*")?.at(1)?.max == 1
	assert p.binding("*")?.at(2)?.text()? == "1"
	assert p.binding_str("*") == '("a" ("test"* !>"abc")? "1")'
}

fn test_braces() ? {
	mut p := new_parser(data: '{"test" "abc"}', debug: 0)?
	p.parse_binding()?
	assert p.binding("*")?.elem is GroupPattern
	assert p.binding("*")?.word_boundary == true
	assert p.binding("*")?.at(0)?.word_boundary == true	// This will be applied to the next pattern, the one following the braces
	assert p.binding("*")?.at(0)?.elem is GroupPattern
	assert (p.binding("*")?.at(0)?.elem as GroupPattern).word_boundary == false	// This is the default for sequences within the group
	assert p.binding("*")?.at(0)?.at(0)?.text()? == "test"
	assert p.binding("*")?.at(0)?.at(0)?.word_boundary == false
	assert p.binding("*")?.at(0)?.at(1)?.text()? == "abc"
	assert p.binding("*")?.at(0)?.at(1)?.word_boundary == false
	assert p.binding_str("*") == '({"test" "abc"})'

	p = new_parser(data: '"a" {"test"* !"abc"}? "1"', debug: 0)?
	p.parse_binding()?
	assert p.binding("*")?.elem is GroupPattern
	assert p.binding("*")?.word_boundary == true
	assert p.binding("*")?.at(0)?.text()? == "a"
	assert p.binding("*")?.at(0)?.word_boundary == true
	assert p.binding("*")?.at(1)?.elem is GroupPattern
	assert p.binding("*")?.at(1)?.word_boundary == true
	assert p.binding("*")?.at(1)?.at(0)?.text()? == "test"
	assert p.binding("*")?.at(1)?.at(0)?.word_boundary == false
	assert p.binding("*")?.at(1)?.at(0)?.min == 0
	assert p.binding("*")?.at(1)?.at(0)?.max == -1
	assert p.binding("*")?.at(1)?.at(1)?.text()? == "abc"
	assert p.binding("*")?.at(1)?.at(1)?.predicate == .negative_look_ahead
	assert p.binding("*")?.at(1)?.at(1)?.word_boundary == false
	assert p.binding("*")?.at(1)?.min == 0
	assert p.binding("*")?.at(1)?.max == 1
	assert p.binding("*")?.at(2)?.text()? == "1"
	assert p.binding_str("*") == '("a" {"test"* !>"abc"}? "1")'
}

fn test_parenthenses_and_braces() ? {
	mut p := new_parser(data: '("test") / {"abc"}', debug: 0)?
	p.parse_binding()?
	assert p.binding("*")?.elem is GroupPattern
	assert p.binding("*")?.word_boundary == true
	assert p.binding("*")?.at(0)?.elem is GroupPattern
	assert p.binding("*")?.at(0)?.word_boundary == true
	assert p.binding("*")?.at(0)?.operator == .choice
	assert p.binding("*")?.at(0)?.at(0)?.text()? == "test"
	assert p.binding("*")?.at(1)?.elem is GroupPattern
	assert (p.binding("*")?.at(1)?.elem as GroupPattern).word_boundary == false
	assert p.binding("*")?.at(1)?.at(0)?.text()? == "abc"
	assert p.binding_str("*") == '(("test") / {"abc"})'

	p = new_parser(data: '("a" {"test"* !"abc"}?) / "1"', debug: 0)?
	p.parse_binding()?
	assert p.binding("*")?.at(0)?.elem is GroupPattern
	assert p.binding("*")?.at(0)?.operator == .choice
	assert p.binding("*")?.at(1)?.text()? == "1"

	assert p.binding("*")?.at(0)?.at(0)?.text()? == "a"
	assert p.binding("*")?.at(0)?.at(1)?.elem is GroupPattern
	assert (p.binding("*")?.at(0)?.at(1)?.elem as GroupPattern).word_boundary == false
	assert p.binding("*")?.at(0)?.at(1)?.min == 0
	assert p.binding("*")?.at(0)?.at(1)?.max == 1

	assert p.binding("*")?.at(0)?.at(1)?.at(0)?.text()? == "test"
	assert p.binding("*")?.at(0)?.at(1)?.at(0)?.min == 0
	assert p.binding("*")?.at(0)?.at(1)?.at(0)?.max == -1
	assert p.binding("*")?.at(0)?.at(1)?.at(0)?.word_boundary == false
	assert p.binding("*")?.at(0)?.at(1)?.at(0)?.operator == .sequence

	assert p.binding("*")?.at(0)?.at(1)?.at(1)?.text()? == "abc"
	assert p.binding_str("*") == '(("a" {"test"* !>"abc"}?) / "1")'
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

	assert p.binding("*")?.elem is GroupPattern
	assert p.binding("*")?.at(0)?.text()? == r'\"'
	assert p.binding("*")?.at(0)?.operator == .choice
	assert p.binding("*")?.at(1)?.text()? == r'\"\"'
	assert p.binding("*")?.at(1)?.operator == .choice
	assert p.binding("*")?.at(2)?.elem is GroupPattern
	assert p.binding_str("*") == r'("\"" / "\"\"" / {[(35)] [(35)]})'	// TODO str() does not yet escape
}

fn test_issue_1() ? {
	// TODO not sure what $ in the charset is really doing. It must somehow add end-of-file flag (and test)
	mut p := new_parser(data: '>{{"."? [[:space:] $]} / [[:punct:] & !"."]}', debug: 0)?
	p.parse_binding()?
	assert p.binding_str("*") == r'({{"."? [(10-14)(33)]} / [(33-46)(48)(59-65)(92)(94-97)(124-127)]})'
}

fn test_rpl_1_2() ? {
	f := r"C:\source_code\vlang\vlang-rosie\modules\rosie\parser/../../../rpl\rosie\rpl_1_2.rpl"
	data := os.read_file(f)?
	mut p := new_parser(data: data, debug: 99) or {
		return error("${err.msg}; file: $f")
	}
	p.parse() or {
		return error("${err.msg}; file: $f")
	}
}
/*
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
*/