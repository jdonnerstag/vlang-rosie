module rpl

import rosie

fn test_parser_empty_data() ? {
	mut p := new_parser()?
	p.parse(data: "")?
}

fn test_parser_comments() ? {
	mut p := new_parser()?
	p.parse(data: "-- comment \n-- another comment")?
}

fn test_parser_language() ? {
	mut p := new_parser()?
	p.parse(module_mode: true, data: "-- comment \n-- another comment\n\nrpl 1.0")?
	assert p.package().language == "1.0"
}

fn test_parser_package() ? {
	mut p := new_parser(debug: 0)?
	p.parse(module_mode: true, data: "-- comment \n-- another comment\n\nrpl 1.0\npackage test")?
	assert p.package().language == "1.0"
	assert p.package().name == "test"

	p = new_parser(debug: 0)?
	p.parse(module_mode: true, data: "package test")?
	assert p.package().language == ""
	assert p.package().name == "test"
}

fn test_simple_binding() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: 'alias ascii = "test" ')?
	assert p.package().get_("ascii")?.public == true
	assert p.pattern("ascii")?.min == 1
	assert p.pattern("ascii")?.max == 1
	assert p.pattern("ascii")?.predicate == rosie.PredicateType.na
	//p.package().print_bindings()
	assert p.pattern("ascii")?.text()? == "test"

	p = new_parser()?
	p.parse(data: 'local alias ascii = "test"')?
	assert p.package().get_("ascii")?.public == false
	assert p.pattern("ascii")?.min == 1
	assert p.pattern("ascii")?.max == 1
	assert p.pattern("ascii")?.predicate == rosie.PredicateType.na
	assert p.pattern("ascii")?.text()? == "test"

	p = new_parser()?
	p.parse(data: 'ascii = "test"')?
	assert p.package().get_("ascii")?.public == true
	assert p.package().get_("ascii")?.alias == false
	assert p.pattern("ascii")?.text()? == "test"

	p = new_parser()?
	p.parse(data: '"test"')?
	assert p.package().get_("*")?.public == true
	assert p.pattern("*")?.min == 1
	assert p.pattern("*")?.max == 1
	assert p.pattern("*")?.predicate == rosie.PredicateType.na
	assert p.pattern("*")?.text()? == "test"
}

fn test_dup_id1() ? {
	mut p := new_parser(debug: 0)?
	if _ := p.parse(data: 'local x = "hello"; local x = "world"') { assert false }

	p = new_parser()?
	if _ := p.parse(data: 'x = "hello"; x = "world"') { assert false }

	p = new_parser()?
	if _ := p.parse(data: 'local x = "hello"; x = "world"') { assert false }

	// This one is a module, so we can test it with 'import'
	p = new_parser()?
	if _ := p.parse(data: 'package foo; local x = "hello"; x = "world"') { assert false }
}

fn test_tilde() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: 'alias ~ = [:space:]+; x = {"a" ~ {"b" ~}? "c"}')?
	//eprintln(p.binding("x")?)
	assert p.pattern("x")?.repr() == '{"a" ~ {"b" ~}? "c"}'
}

fn test_disjunction() ? {
	// -- If you are used to regex, the tagname expression below will look quite strange.  But
	// -- in RPL, a bracket expression is a disjunction of its contents, and inside a bracket
	// -- expression you can use literals like "/>" and even reference other patterns.
	mut p := new_parser()?
	p.parse(data: 'tagname = [^ [:space:] [>] "/>"]+')?
	//eprintln(p.binding("x")?)
	assert p.pattern("tagname")?.repr() == '[^ [(9-13)(32)(62)] "/>"]+'
}

fn test_builtin_override() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: r'builtin alias ~ = [ ]+; x = {"a" ~ "b"}')?
	assert p.pattern("~")?.repr() == '[(32)]+'
	assert p.package_cache.get(rosie.builtin)?.get_("~")?.pattern.repr() == '[(32)]+'
}
/* */