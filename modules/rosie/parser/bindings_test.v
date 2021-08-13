module parser


fn test_parser_empty_data() ? {
	p := new_parser(data: "")?
}

fn test_parser_comments() ? {
	p := new_parser(data: "-- comment \n-- another comment")?
}

fn test_parser_language() ? {
	p := new_parser(data: "-- comment \n-- another comment\n\nrpl 1.0", debug: 0)?
	assert p.package().language == "1.0"
}

fn test_parser_package() ? {
	mut p := new_parser(data: "-- comment \n-- another comment\n\nrpl 1.0\npackage test", debug: 0)?
	assert p.package().language == "1.0"
	assert p.package().name == "test"

	p = new_parser(data: "package test", debug: 0)?
	assert p.package().language == ""
	assert p.package().name == "test"
}

fn test_simple_binding() ? {
	mut p := new_parser(data: 'alias ascii = "test" ', debug: 0)?
	p.parse_binding()?
	assert p.package().get_("ascii")?.public == true
	assert p.pattern("ascii")?.min == 1
	assert p.pattern("ascii")?.max == 1
	assert p.pattern("ascii")?.predicate == PredicateType.na
	assert p.pattern("ascii")?.text()? == "test"

	p = new_parser(data: 'local alias ascii = "test"', debug: 0)?
	p.parse_binding()?
	assert p.package().get_("ascii")?.public == false
	assert p.pattern("ascii")?.min == 1
	assert p.pattern("ascii")?.max == 1
	assert p.pattern("ascii")?.predicate == PredicateType.na
	assert p.pattern("ascii")?.text()? == "test"

	p = new_parser(data: 'ascii = "test"', debug: 0)?
	p.parse_binding()?
	assert p.package().get_("ascii")?.public == true
	assert p.package().get_("ascii")?.alias == false
	assert p.pattern("ascii")?.text()? == "test"

	p = new_parser(data: '"test"', debug: 0)?
	p.parse_binding()?
	assert p.package().get_("*")?.public == true
	assert p.pattern("*")?.min == 1
	assert p.pattern("*")?.max == 1
	assert p.pattern("*")?.predicate == PredicateType.na
	assert p.pattern("*")?.text()? == "test"
}
