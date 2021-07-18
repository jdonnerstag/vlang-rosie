module parser

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
	assert p.binding("ascii").etype == .literal
	assert p.binding("ascii").text == "test"

	p = new_parser(data: 'local alias ascii = "test" ', debug: 99)?
	p.parse_binding()?
	assert p.bindings["ascii"].public == false
	assert p.binding("ascii").etype == .literal
	assert p.binding("ascii").text == "test"

	p = new_parser(data: '"test"', debug: 99)?
	p.parse_binding()?
	assert p.bindings["*"].public == true
	assert p.binding("*").etype == .literal
	assert p.binding("*").text == "test"
}

fn test_multiplier() ? {
	mut p := new_parser(data: '"test"', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").etype == .literal
	assert p.binding("*").min == 1
	assert p.binding("*").max == 1

	p = new_parser(data: '"test"*', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").etype == .literal
	assert p.binding("*").min == 0
	assert p.binding("*").max == -1

	p = new_parser(data: '"test"+', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").etype == .literal
	assert p.binding("*").min == 1
	assert p.binding("*").max == -1

	p = new_parser(data: '"test"?', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").etype == .literal
	assert p.binding("*").min == 0
	assert p.binding("*").max == 1

	p = new_parser(data: '"test"{2,4}', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").etype == .literal
	assert p.binding("*").min == 2
	assert p.binding("*").max == 4

	p = new_parser(data: '"test"{,4}', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").etype == .literal
	assert p.binding("*").min == 0
	assert p.binding("*").max == 4

	p = new_parser(data: '"test"{4,}', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").etype == .literal
	assert p.binding("*").min == 4
	assert p.binding("*").max == -1

	p = new_parser(data: '"test"{,}', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").etype == .literal
	assert p.binding("*").min == 0
	assert p.binding("*").max == -1
}

fn test_choice() ? {
	mut p := new_parser(data: '"test" / "abc"', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").etype == .choice
	assert p.binding("*").sub(p, 0).etype == .literal
	assert p.binding("*").sub(p, 0).text == "test"
	assert p.binding("*").sub(p, 1).etype == .literal
	assert p.binding("*").sub(p, 1).text == "abc"

	p = new_parser(data: '"test"* / !"abc" / "1"', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").etype == .choice

	p.print("*")
	assert p.binding("*").sub(p, 0).etype == .literal
	assert p.binding("*").sub(p, 0).text == "test"
	assert p.binding("*").sub(p, 0).min == 0
	assert p.binding("*").sub(p, 0).max == -1

	assert p.binding("*").sub(p, 1).etype == .negative_look_ahead
	assert p.binding("*").sub(p, 1).text == "abc"

	assert p.binding("*").sub(p, 2).etype == .literal
	assert p.binding("*").sub(p, 2).text == "1"
}

fn test_sequence() ? {
	mut p := new_parser(data: '"test" "abc"', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").etype == .sequence
	assert p.binding("*").sub(p, 0).etype == .literal
	assert p.binding("*").sub(p, 0).text == "test"
	assert p.binding("*").sub(p, 1).etype == .literal
	assert p.binding("*").sub(p, 1).text == "abc"

	p = new_parser(data: '"test"* !"abc" "1"', debug: 99)?
	p.parse_binding()?
	assert p.binding("*").etype == .sequence

	p.print("*")
	assert p.binding("*").sub(p, 0).etype == .literal
	assert p.binding("*").sub(p, 0).text == "test"
	assert p.binding("*").sub(p, 0).min == 0
	assert p.binding("*").sub(p, 0).max == -1

	assert p.binding("*").sub(p, 1).etype == .negative_look_ahead
	assert p.binding("*").sub(p, 1).text == "abc"
	
	assert p.binding("*").sub(p, 2).etype == .literal
	assert p.binding("*").sub(p, 2).text == "1"
}
