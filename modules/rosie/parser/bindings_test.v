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

fn test_dup_id1() ? {
	mut p := new_parser(data: 'local x = "hello"; local x = "world"', debug: 0)?
	if _ := p.parse() { assert false }

	p = new_parser(data: 'x = "hello"; x = "world"', debug: 0)?
	if _ := p.parse() { assert false }

	p = new_parser(data: 'local x = "hello"; x = "world"', debug: 0)?
	if _ := p.parse() { assert false }

	// This one is a module, so we can test it with 'import'
	p = new_parser(data: 'package foo; local x = "hello"; x = "world"', debug: 0)?
	if _ := p.parse() { assert false }
}

fn test_tilde() ? {
	mut p := new_parser(data: 'alias ~ = [:space:]+; x = {"a" ~ {"b" ~}? "c"}', debug: 0)?
	p.parse()?
	//eprintln(p.binding("x")?)
	assert p.pattern("x")?.repr() == '{"a" ~ {"b" ~}? "c"}'
}

fn test_disjunction() ? {
	// -- If you are used to regex, the tagname expression below will look quite strange.  But
	// -- in RPL, a bracket expression is a disjunction of its contents, and inside a bracket
	// -- expression you can use literals like "/>" and even reference other patterns.
	mut p := new_parser(data: 'tagname = [^ [:space:] [>] "/>"]+', debug: 0)?
	p.parse()?
	//eprintln(p.binding("x")?)
	assert p.pattern("tagname")?.repr() == '[^ [(9-13)(32)(62)] "/>"]+'
}

fn test_builtin_override() ? {
	mut p := new_parser(data: r'builtin alias ~ = [ ]+; x = {"a" ~ "b"}', debug: 3)?
	p.parse()?
	assert p.pattern("~")?.repr() == '[(32)]+'
	assert p.package_cache.get(builtin)?.get_("~")?.pattern.repr() == '[(32)]+'
}
/* */