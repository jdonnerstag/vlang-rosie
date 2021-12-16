module core_0

import rosie

fn test_parser_empty_data() ? {
	mut p := new_parser()?
	if _ := p.parse(data: "") { assert false }
	p.parse(data: '"a"')?
}

fn test_parser_comments() ? {
	mut p := new_parser()?
	p.parse(data: "-- comment \n-- another comment")?
}

fn test_parser_language() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: "-- comment \n-- another comment\n\nrpl 1.0")?
	assert p.main.language == "1.0"
}

fn test_parser_package() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: "-- comment \n-- another comment\n\nrpl 1.0\npackage test")?
	assert p.main.language == "1.0"
	assert p.main.name == "test"

	// You can call parse() multiple times. No new package will be created.
	if _ := p.parse(data: "package test") { assert false }
	if _ := p.main.package_cache.get("test2") { assert false }
	p.parse(data: "package test2")?
	assert p.main.language == "1.0"
	assert p.main.name == "test2"
}

fn test_simple_binding() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: 'alias ascii = "test" ')?
	assert p.main.get_("ascii")?.public == true
	assert p.pattern("ascii")?.min == 1
	assert p.pattern("ascii")?.max == 1
	assert p.pattern("ascii")?.predicate == rosie.PredicateType.na
	assert p.pattern("ascii")?.text()? == "test"

	p = new_parser(debug: 0)?
	p.parse(data: 'local alias ascii = "test"')?
	assert p.main.get_("ascii")?.public == false
	assert p.pattern("ascii")?.min == 1
	assert p.pattern("ascii")?.max == 1
	assert p.pattern("ascii")?.predicate == rosie.PredicateType.na
	assert p.pattern("ascii")?.text()? == "test"

	p = new_parser(debug: 0)?
	p.parse(data: 'ascii = "test"')?
	assert p.main.get_("ascii")?.public == true
	assert p.main.get_("ascii")?.alias == false
	assert p.pattern("ascii")?.text()? == "test"

	p = new_parser(debug: 0)?
	p.parse(data: '"test"')?
	assert p.main.get_("*")?.public == true
	assert p.pattern("*")?.min == 1
	assert p.pattern("*")?.max == 1
	assert p.pattern("*")?.predicate == rosie.PredicateType.na
	assert p.pattern("*")?.text()? == "test"
}

fn test_dup_id1() ? {
	mut p := new_parser(debug: 0)?
	if _ := p.parse(data: 'local x = "hello"; local x = "world"') { assert false }
	if _ := p.parse(data: 'x = "hello"; x = "world"') { assert false }
	if _ := p.parse(data: 'local x = "hello"; x = "world"') { assert false }

	// This one is a module, so we can test it with 'import'
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
	mut p := new_parser(debug: 0)?
	p.parse(data: 'tagname = [^ [:space:] [>] "/>"]+')?
	//eprintln(p.binding("x")?)
	assert p.pattern("tagname")?.repr() == '[^ [(9-13)(32)(62)] "/>"]+'
}

fn test_builtin_override() ? {
	mut p := new_parser(debug: 0)?
	assert p.main.package_cache.names() == ["builtin"]
	assert p.main.package_cache.get(rosie.builtin)?.name == p.main.package_cache.builtin().name
	assert voidptr(p.main.parent) != voidptr(0)
	assert p.main.parent.name == p.main.package_cache.builtin().name
	p.parse(data: r'builtin alias ~ = [ ]+; x = {"a" ~ "b"}')?
	assert p.pattern("~")?.repr() == '[(32)]+'
	assert p.main.package_cache.get(rosie.builtin)?.get_("~")?.pattern.repr() == '[(32)]+'
}
/* */