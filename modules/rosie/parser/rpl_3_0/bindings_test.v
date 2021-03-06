module rpl_3_0

import rosie

fn test_parser_empty_data() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: '"a"')?  // RPL 3.0 does support both, ".." and '..'

	p = new_parser(debug: 0)?
	p.parse(data: "'a'")?  // RPL 3.0 does support '..' quotes, whereas 1.3 only supports ".."
}

fn test_parser_comments() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: "-- comment \n-- another comment")?
}

fn test_parser_package() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: "-- comment \n-- another comment\n\nrpl 1.0\npackage test") or {
		assert err.code == rosie.err_rpl_version_not_supported
	}

	p = new_parser(debug: 0)?
	p.parse(data: "-- comment \n-- another comment\n\nrpl 3.0\npackage test")?
	assert p.package().language == "3.0"
	assert p.package().name == "test"

	p = new_parser(debug: 0)?
	p.parse(data: "package test")?
	assert p.package().language == ""
	assert p.package().name == "test"
}

fn test_simple_binding() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: 'alias ascii = "test" ')?
	assert p.binding("ascii")?.public == true
	assert p.binding("ascii")?.alias == true
	assert p.pattern("ascii")?.min == 1
	assert p.pattern("ascii")?.max == 1
	assert p.pattern("ascii")?.predicate == rosie.PredicateType.na
	//p.main.print_bindings()
	assert p.pattern("ascii")?.repr() == '{"test"}'

	p = new_parser()?
	p.parse(data: 'ascii = "test"')?
	assert p.binding("ascii")?.public == true
	assert p.binding("ascii")?.alias == false
	assert p.pattern("ascii")?.repr() == '{"test"}'

	p = new_parser()?
	p.parse(data: '"test"')?
	assert p.binding("*")?.public == true
	assert p.binding("*")?.alias == false
	assert p.pattern("*")?.min == 1
	assert p.pattern("*")?.max == 1
	assert p.pattern("*")?.predicate == rosie.PredicateType.na
	assert p.pattern("*")?.repr() == '{"test"}'
}

fn test_dup_id1() ? {
	mut p := new_parser(debug: 0)?
	if _ := p.parse(data: 'alias x = "hello"; alias x = "world"') { assert false }

	p = new_parser()?
	if _ := p.parse(data: 'x = "hello"; x = "world"') { assert false }

	p = new_parser()?
	if _ := p.parse(data: 'alias x = "hello"; x = "world"') { assert false }

	// This one is a module, so we can test it with 'import'
	p = new_parser()?
	if _ := p.parse(data: 'package foo; alias x = "hello"; x = "world"') { assert false }
}

fn test_tilde() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: 'alias ~ = [:space:]+; x = ("a" ~ ("b" ~)? "c")')?
	//eprintln(p.binding("x")?)
	assert p.pattern("x")?.repr() == '{{"a" ~ {"b" ~}? "c"}}'
}

fn test_disjunction() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: 'tagname = [^ [:space:] [>]]+')?
	p.main.print_bindings()
	assert p.pattern("tagname")?.repr() == '{[(0-8)(14-31)(33-61)(63-255)]+}'
}

fn test_builtin_override() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: r'alias ~ [builtin] = [ ]+; x = ("a" ~ "b")')?
	assert p.current.has_parent() == true
	assert p.current.builtin().name == p.package_cache.builtin().name
	assert p.current.builtin().has_binding("~")
	assert p.current.parent.name == rosie.builtin
	assert p.pattern("~")?.repr() == '{[(32)]+}'	// TODO we output rpl 1.3 format, not 3.0
	assert p.package_cache.builtin().get_internal("~")?.pattern.repr() == '{[(32)]+}'
}
/* */