module parser

import os
import rosie.runtime as rt

fn test_parser_empty_data() ? {
	p := new_parser(data: "")?
}

fn test_parser_comments() ? {
	p := new_parser(data: "-- comment \n-- another comment")?
}

fn test_parser_language() ? {
	p := new_parser(data: "-- comment \n-- another comment\n\nrpl 1.0", debug: 99)?
	assert p.language == "1.0"
}

fn test_parser_package() ? {
	mut p := new_parser(data: "-- comment \n-- another comment\n\nrpl 1.0\npackage test", debug: 99)?
	assert p.language == "1.0"
	assert p.package == "test"

	p = new_parser(data: "package test", debug: 99)?
	assert p.language == ""
	assert p.package == "test"
}

fn test_parser_import() ? {
	mut p := new_parser(data: "-- comment \n-- another comment\n\nrpl 1.0\npackage test\nimport net", debug: 99)?
	assert p.language == "1.0"
	assert p.package == "test"
	assert "net" in p.import_stmts

	p = new_parser(data: "import net", debug: 99)?
	assert p.language == ""
	assert p.package == ""
	assert "net" in p.import_stmts

	p = new_parser(data: "import net, word", debug: 99)?
	assert p.language == ""
	assert p.package == ""
	assert "net" in p.import_stmts
	assert "word" in p.import_stmts

	p = new_parser(data: 'import net as n, "word" as w', debug: 99)?
	assert p.language == ""
	assert p.package == ""
	assert "n" in p.import_stmts
	assert p.import_stmts["n"].name == "net"
	assert "w" in p.import_stmts
	assert p.import_stmts["w"].name == "word"
}

fn test_simple_binding() ? {
	mut p := new_parser(data: 'alias ascii = "test" ', debug: 99)?
	p.parse_binding()?
	assert p.bindings["ascii"].public == true
	assert p.binding("ascii").min == 1
	assert p.binding("ascii").max == 1
	assert p.binding("ascii").predicate == PredicateType.na

	assert p.binding("ascii").at(0)?.text()? == "test"
	assert p.binding("ascii").at(0)?.min == 1
	assert p.binding("ascii").at(0)?.max == 1
	assert p.binding("ascii").at(0)?.predicate == PredicateType.na

	p = new_parser(data: 'local alias ascii = "test"', debug: 99)?
	p.parse_binding()?
	assert p.bindings["ascii"].public == false
	assert p.binding("ascii").min == 1
	assert p.binding("ascii").max == 1
	assert p.binding("ascii").predicate == PredicateType.na
	assert p.binding("ascii").at(0)?.text()? == "test"

	p = new_parser(data: '"test"', debug: 99)?
	p.parse_binding()?
	assert p.bindings["*"].public == true
	assert p.binding("*").min == 1
	assert p.binding("*").max == 1
	assert p.binding("*").predicate == PredicateType.na
	assert p.binding("*").at(0)?.text()? == "test"
}

fn test_multiplier() ? {
	mut p := new_parser(data: '"test"', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").at(0)?.min == 1
	assert p.binding("*").at(0)?.max == 1

	p = new_parser(data: '"test"*', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").at(0)?.min == 0
	assert p.binding("*").at(0)?.max == -1

	p = new_parser(data: '"test"+', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").at(0)?.min == 1
	assert p.binding("*").at(0)?.max == -1

	p = new_parser(data: '"test"?', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").at(0)?.min == 0
	assert p.binding("*").at(0)?.max == 1

	p = new_parser(data: '"test"{2,4}', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").at(0)?.min == 2
	assert p.binding("*").at(0)?.max == 4

	p = new_parser(data: '"test"{,4}', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").at(0)?.min == 0
	assert p.binding("*").at(0)?.max == 4

	p = new_parser(data: '"test"{4,}', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").at(0)?.min == 4
	assert p.binding("*").at(0)?.max == -1

	p = new_parser(data: '"test"{,}', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").at(0)?.min == 0
	assert p.binding("*").at(0)?.max == -1
}

// TODO need tests for predicates

fn test_choice() ? {
	mut p := new_parser(data: '"test" / "abc"', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").at(0)?.text()? == "test"
	assert p.binding("*").at(0)?.operator == .choice
	assert p.binding("*").at(1)?.text()? == "abc"

	p = new_parser(data: '"test"* / !"abc" / "1"', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").at(0)?.text()? == "test"
	assert p.binding("*").at(0)?.min == 0
	assert p.binding("*").at(0)?.max == -1
	assert p.binding("*").at(0)?.operator == .choice
	assert p.binding("*").at(1)?.text()? == "abc"
	assert p.binding("*").at(1)?.predicate == .negative_look_ahead
	assert p.binding("*").at(1)?.operator == .choice
	assert p.binding("*").at(2)?.text()? == "1"

	p = new_parser(data: '"test"* <"abc" / "1"', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").at(0)?.text()? == "test"
	assert p.binding("*").at(0)?.min == 0
	assert p.binding("*").at(0)?.max == -1
	assert p.binding("*").at(0)?.operator == .sequence
	assert p.binding("*").at(1)?.text()? == "abc"
	assert p.binding("*").at(1)?.predicate == .look_behind
	assert p.binding("*").at(1)?.operator == .choice
	assert p.binding("*").at(2)?.text()? == "1"
}

fn test_sequence() ? {
	mut p := new_parser(data: '"test" "abc"', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").at(0)?.text()? == "test"
	assert p.binding("*").at(0)?.operator == .sequence
	assert p.binding("*").at(1)?.text()? == "abc"

	p = new_parser(data: '"test"* !"abc" "1"', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").at(0)?.text()? == "test"
	assert p.binding("*").at(0)?.operator == .sequence
	assert p.binding("*").at(0)?.min == 0
	assert p.binding("*").at(0)?.max == -1
	assert p.binding("*").at(1)?.text()? == "abc"
	assert p.binding("*").at(1)?.operator == .sequence
	assert p.binding("*").at(1)?.min == 1
	assert p.binding("*").at(1)?.max == 1
	assert p.binding("*").at(2)?.text()? == "1"
	assert p.binding("*").at(2)?.min == 1
	assert p.binding("*").at(2)?.max == 1
}

fn test_parenthenses() ? {
	mut p := new_parser(data: '("test" "abc")', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").at(0)?.elem is GroupPattern
	assert p.binding("*").at(0)?.at(0)?.text()? == "test"
	assert p.binding("*").at(0)?.at(1)?.text()? == "abc"

	p = new_parser(data: '"a" ("test"* !"abc")? "1"', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").at(0)?.text()? == "a"
	assert p.binding("*").at(1)?.elem is GroupPattern
	assert p.binding("*").at(1)?.at(0)?.text()? == "test"
	assert p.binding("*").at(1)?.at(0)?.min == 0
	assert p.binding("*").at(1)?.at(0)?.max == -1
	assert p.binding("*").at(1)?.at(1)?.text()? == "abc"
	assert p.binding("*").at(1)?.at(1)?.predicate == .negative_look_ahead
	assert p.binding("*").at(1)?.min == 0
	assert p.binding("*").at(1)?.max == 1
	assert p.binding("*").at(2)?.text()? == "1"
}

fn test_braces() ? {
	mut p := new_parser(data: '{"test" "abc"}', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").elem is GroupPattern
	assert p.binding("*").word_boundary == true
	assert p.binding("*").at(0)?.word_boundary == true	// This will be applied to the next pattern, the one following the braces
	assert p.binding("*").at(0)?.elem is GroupPattern
	assert (p.binding("*").at(0)?.elem as GroupPattern).word_boundary == false	// This is the default for sequences within the group
	assert p.binding("*").at(0)?.at(0)?.text()? == "test"
	assert p.binding("*").at(0)?.at(0)?.word_boundary == false
	assert p.binding("*").at(0)?.at(1)?.text()? == "abc"
	assert p.binding("*").at(0)?.at(1)?.word_boundary == false

	p = new_parser(data: '"a" {"test"* !"abc"}? "1"', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").elem is GroupPattern
	assert p.binding("*").word_boundary == true
	assert p.binding("*").at(0)?.text()? == "a"
	assert p.binding("*").at(0)?.word_boundary == true
	assert p.binding("*").at(1)?.elem is GroupPattern
	assert p.binding("*").at(1)?.word_boundary == true
	assert p.binding("*").at(1)?.at(0)?.text()? == "test"
	assert p.binding("*").at(1)?.at(0)?.word_boundary == false
	assert p.binding("*").at(1)?.at(0)?.min == 0
	assert p.binding("*").at(1)?.at(0)?.max == -1
	assert p.binding("*").at(1)?.at(1)?.text()? == "abc"
	assert p.binding("*").at(1)?.at(1)?.predicate == .negative_look_ahead
	assert p.binding("*").at(1)?.at(1)?.word_boundary == false
	assert p.binding("*").at(1)?.min == 0
	assert p.binding("*").at(1)?.max == 1
	assert p.binding("*").at(2)?.text()? == "1"
}

fn test_parenthenses_and_braces() ? {
	mut p := new_parser(data: '("test") / {"abc"}', debug: 99)?
	p.parse_binding()?
	p.print("*")

	assert p.binding("*").elem is GroupPattern
	assert p.binding("*").word_boundary == true
	assert p.binding("*").at(0)?.elem is GroupPattern
	assert p.binding("*").at(0)?.word_boundary == true
	assert p.binding("*").at(0)?.operator == .choice
	assert p.binding("*").at(0)?.at(0)?.text()? == "test"
	assert p.binding("*").at(1)?.elem is GroupPattern
	assert (p.binding("*").at(1)?.elem as GroupPattern).word_boundary == false
	assert p.binding("*").at(1)?.at(0)?.text()? == "abc"

	p = new_parser(data: '("a" {"test"* !"abc"}?) / "1"', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").at(0)?.elem is GroupPattern
	assert p.binding("*").at(0)?.operator == .choice
	assert p.binding("*").at(1)?.text()? == "1"

	assert p.binding("*").at(0)?.at(0)?.text()? == "a"
	assert p.binding("*").at(0)?.at(1)?.elem is GroupPattern
	assert (p.binding("*").at(0)?.at(1)?.elem as GroupPattern).word_boundary == false
	assert p.binding("*").at(0)?.at(1)?.min == 0
	assert p.binding("*").at(0)?.at(1)?.max == 1

	assert p.binding("*").at(0)?.at(1)?.at(0)?.text()? == "test"
	assert p.binding("*").at(0)?.at(1)?.at(0)?.min == 0
	assert p.binding("*").at(0)?.at(1)?.at(0)?.max == -1
	assert p.binding("*").at(0)?.at(1)?.at(0)?.word_boundary == false
	assert p.binding("*").at(0)?.at(1)?.at(0)?.operator == .sequence

	assert p.binding("*").at(0)?.at(1)?.at(1)?.text()? == "abc"
}

fn test_parse_charset() ? {
	mut p := new_parser(data: '[:digit:]', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").elem is GroupPattern
	assert p.binding("*").at(0)?.elem is CharsetPattern

	p = new_parser(data: '[:^digit:]', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").at(0)?.elem is CharsetPattern

	p = new_parser(data: '[a-z]', debug: 99)?
	p.parse_binding()?

	p = new_parser(data: '[^a-f]', debug: 99)?
	p.parse_binding()?

	p = new_parser(data: '[abcdef]', debug: 99)?
	p.parse_binding()?

	p = new_parser(data: '[^abcdef]', debug: 99)?
	p.parse_binding()?

	p = new_parser(data: '[[:digit:][a-f]]', debug: 99)?
	p.parse_binding()?

	p = new_parser(data: '[[:digit:][abcdef]]', debug: 99)?
	p.parse_binding()?

	p = new_parser(data: '[^[:digit:][a-f]]', debug: 99)?
	p.parse_binding()?

	p = new_parser(data: '[0x00-0x1f]', debug: 99)?
	p.parse_binding()?
	x := p.binding("*")

	p = new_parser(data: '[[:digit:] cs2]', debug: 99)?
	p.bindings["cs2"] = Binding{ name: "cs2", pattern: x }
	p.parse_binding()?
}
/*
fn test_parse_orig_rosie_rpl_files() ? {
    rplx_file := os.dir(@FILE) + "/../../../rpl"
	eprintln("rpl dir: $rplx_file")
	files := os.walk_ext(rplx_file, "rpl")
	for f in files {
		eprintln("file: $f")
		data := os.read_file(f)?
		mut p := new_parser(data: data, debug: 99)?
		p.parse()?
		assert false
	}
	assert false
}
 */
