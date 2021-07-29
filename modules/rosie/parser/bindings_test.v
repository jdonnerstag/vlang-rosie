module parser

import os

fn test_parser_empty_data() ? {
	p := new_parser(data: "")?
}

fn test_parser_comments() ? {
	p := new_parser(data: "-- comment \n-- another comment")?
}

fn test_parser_language() ? {
	p := new_parser(data: "-- comment \n-- another comment\n\nrpl 1.0", debug: 0)?
	assert p.language == "1.0"
}

fn test_parser_package() ? {
	mut p := new_parser(data: "-- comment \n-- another comment\n\nrpl 1.0\npackage test", debug: 0)?
	assert p.language == "1.0"
	assert p.package == "test"

	p = new_parser(data: "package test", debug: 0)?
	assert p.language == ""
	assert p.package == "test"
}

fn test_simple_binding() ? {
	mut p := new_parser(data: 'alias ascii = "test" ', debug: 0)?
	p.parse_binding("main")?
	assert p.packages["main"].bindings["ascii"].public == true
	assert p.binding("ascii")?.min == 1
	assert p.binding("ascii")?.max == 1
	assert p.binding("ascii")?.predicate == PredicateType.na

	assert p.binding("ascii")?.at(0)?.text()? == "test"
	assert p.binding("ascii")?.at(0)?.min == 1
	assert p.binding("ascii")?.at(0)?.max == 1
	assert p.binding("ascii")?.at(0)?.predicate == PredicateType.na

	p = new_parser(data: 'local alias ascii = "test"', debug: 0)?
	p.parse_binding("main")?
	assert p.packages["main"].bindings["ascii"].public == false
	assert p.binding("ascii")?.min == 1
	assert p.binding("ascii")?.max == 1
	assert p.binding("ascii")?.predicate == PredicateType.na
	assert p.binding("ascii")?.at(0)?.text()? == "test"

	p = new_parser(data: 'ascii = "test"', debug: 0)?
	p.parse_binding("main")?
	assert p.packages["main"].bindings["ascii"].public == true
	assert p.packages["main"].bindings["ascii"].alias == false
	assert p.binding("ascii")?.at(0)?.text()? == "test"

	p = new_parser(data: '"test"', debug: 0)?
	p.parse_binding("main")?
	assert p.packages["main"].bindings["*"].public == true
	assert p.binding("*")?.min == 1
	assert p.binding("*")?.max == 1
	assert p.binding("*")?.predicate == PredicateType.na
	assert p.binding("*")?.at(0)?.text()? == "test"
}
