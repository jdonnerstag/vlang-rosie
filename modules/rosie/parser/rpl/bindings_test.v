module rpl


fn test_parser_empty_data() ? {
	mut p := new_parser()?
	p.parse("")?
}

fn test_parser_comments() ? {
	mut p := new_parser()?
	p.parse("-- comment \n-- another comment")?
}

fn test_parser_language() ? {
	mut p := new_parser(rpl_type: .rpl_module)?
	p.parse("-- comment \n-- another comment\n\nrpl 1.0")?
	assert p.package().language == "1.0"
}

fn test_parser_package() ? {
	mut p := new_parser(rpl_type: .rpl_module, debug: 0)?
	p.parse("-- comment \n-- another comment\n\nrpl 1.0\npackage test")?
	assert p.package().language == "1.0"
	assert p.package().name == "test"

	p = new_parser(rpl_type: .rpl_module)?
	p.parse("package test")?
	assert p.package().language == ""
	assert p.package().name == "test"
}

fn test_simple_binding() ? {
	mut p := new_parser(debug: 0)?
	p.parse('alias ascii = "test" ')?
	assert p.package().get_("ascii")?.public == true
	assert p.pattern("ascii")?.min == 1
	assert p.pattern("ascii")?.max == 1
	assert p.pattern("ascii")?.predicate == PredicateType.na
	//p.package().print_bindings()
	assert p.pattern("ascii")?.text()? == "test"

	p = new_parser()?
	p.parse('local alias ascii = "test"')?
	assert p.package().get_("ascii")?.public == false
	assert p.pattern("ascii")?.min == 1
	assert p.pattern("ascii")?.max == 1
	assert p.pattern("ascii")?.predicate == PredicateType.na
	assert p.pattern("ascii")?.text()? == "test"

	p = new_parser()?
	p.parse('ascii = "test"')?
	assert p.package().get_("ascii")?.public == true
	assert p.package().get_("ascii")?.alias == false
	assert p.pattern("ascii")?.text()? == "test"

	p = new_parser()?
	p.parse('"test"')?
	assert p.package().get_("*")?.public == true
	assert p.pattern("*")?.min == 1
	assert p.pattern("*")?.max == 1
	assert p.pattern("*")?.predicate == PredicateType.na
	assert p.pattern("*")?.text()? == "test"
}

fn test_dup_id1() ? {
	mut p := new_parser(debug: 0)?
	if _ := p.parse('local x = "hello"; local x = "world"') { assert false }

	p = new_parser()?
	if _ := p.parse('x = "hello"; x = "world"') { assert false }

	p = new_parser()?
	if _ := p.parse('local x = "hello"; x = "world"') { assert false }

	// This one is a module, so we can test it with 'import'
	p = new_parser()?
	if _ := p.parse('package foo; local x = "hello"; x = "world"') { assert false }
}

fn test_tilde() ? {
	mut p := new_parser(debug: 0)?
	p.parse('alias ~ = [:space:]+; x = {"a" ~ {"b" ~}? "c"}')?
	//eprintln(p.binding("x")?)
	assert p.pattern("x")?.repr() == '{"a" ~ {"b" ~}? "c"}'
}

fn test_disjunction() ? {
	// -- If you are used to regex, the tagname expression below will look quite strange.  But
	// -- in RPL, a bracket expression is a disjunction of its contents, and inside a bracket
	// -- expression you can use literals like "/>" and even reference other patterns.
	mut p := new_parser()?
	p.parse('tagname = [^ [:space:] [>] "/>"]+')?
	//eprintln(p.binding("x")?)
	assert p.pattern("tagname")?.repr() == '[^ [(9-13)(32)(62)] "/>"]+'
}

fn test_builtin_override() ? {
	mut p := new_parser()?
	p.parse(r'builtin alias ~ = [ ]+; x = {"a" ~ "b"}')?
	assert p.pattern("~")?.repr() == '[(32)]+'
	assert p.package_cache.get(builtin)?.get_("~")?.pattern.repr() == '[(32)]+'
}
/* */