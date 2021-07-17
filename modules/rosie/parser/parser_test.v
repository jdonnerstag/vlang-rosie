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
	assert p.bindings["ascii"].expr.expr is LiteralExpressionType
	mut x := p.bindings["ascii"].expr.expr as LiteralExpressionType
	assert x.text == "test"

	p = new_parser(data: 'local alias ascii = "test" ', debug: 99)?
	p.parse_binding()?
	assert p.bindings["ascii"].public == false
	assert p.bindings["ascii"].expr.expr is LiteralExpressionType
	x = p.bindings["ascii"].expr.expr as LiteralExpressionType
	assert x.text == "test"

	p = new_parser(data: '"test"', debug: 99)?
	p.parse_binding()?
	assert p.bindings["*"].public == true
	assert p.bindings["*"].expr.expr is LiteralExpressionType
	x = p.bindings["*"].expr.expr as LiteralExpressionType
	assert x.text == "test"
}

fn test_multiplier() ? {
	mut p := new_parser(data: '"test"', debug: 99)?
	p.parse_binding()?
	assert p.bindings["*"].expr.expr is LiteralExpressionType
	assert p.bindings["*"].expr.min == 1
	assert p.bindings["*"].expr.max == 1

	p = new_parser(data: '"test"*', debug: 99)?
	p.parse_binding()?
	assert p.bindings["*"].expr.expr is LiteralExpressionType
	assert p.bindings["*"].expr.min == 0
	assert p.bindings["*"].expr.max == -1

	p = new_parser(data: '"test"+', debug: 99)?
	p.parse_binding()?
	assert p.bindings["*"].expr.expr is LiteralExpressionType
	assert p.bindings["*"].expr.min == 1
	assert p.bindings["*"].expr.max == -1

	p = new_parser(data: '"test"?', debug: 99)?
	p.parse_binding()?
	assert p.bindings["*"].expr.expr is LiteralExpressionType
	assert p.bindings["*"].expr.min == 0
	assert p.bindings["*"].expr.max == 1

	p = new_parser(data: '"test"{2,4}', debug: 99)?
	p.parse_binding()?
	assert p.bindings["*"].expr.expr is LiteralExpressionType
	assert p.bindings["*"].expr.min == 2
	assert p.bindings["*"].expr.max == 4

	p = new_parser(data: '"test"{,4}', debug: 99)?
	p.parse_binding()?
	assert p.bindings["*"].expr.expr is LiteralExpressionType
	assert p.bindings["*"].expr.min == 0
	assert p.bindings["*"].expr.max == 4

	p = new_parser(data: '"test"{4,}', debug: 99)?
	p.parse_binding()?
	assert p.bindings["*"].expr.expr is LiteralExpressionType
	assert p.bindings["*"].expr.min == 4
	assert p.bindings["*"].expr.max == -1

	p = new_parser(data: '"test"{,}', debug: 99)?
	p.parse_binding()?
	assert p.bindings["*"].expr.expr is LiteralExpressionType
	assert p.bindings["*"].expr.min == 0
	assert p.bindings["*"].expr.max == -1
}

fn test_choice() ? {
	mut p := new_parser(data: '"test" / "abc"', debug: 99)?
	p.parse_binding()?
	assert p.bindings["*"].expr.expr is ChoiceExpressionType
	assert (p.bindings["*"].expr.expr as ChoiceExpressionType).p.expr is LiteralExpressionType
	assert (p.bindings["*"].expr.expr as ChoiceExpressionType).q.expr is LiteralExpressionType
	assert ((p.bindings["*"].expr.expr as ChoiceExpressionType).p.expr as LiteralExpressionType).text == "test"
	assert ((p.bindings["*"].expr.expr as ChoiceExpressionType).q.expr as LiteralExpressionType).text == "abc"

	p = new_parser(data: '"test"* / !"abc" / "1"', debug: 99)?
	p.parse_binding()?
	assert p.bindings["*"].expr.expr is ChoiceExpressionType

	assert (p.bindings["*"].expr.expr as ChoiceExpressionType).p.expr is LiteralExpressionType
	assert ((p.bindings["*"].expr.expr as ChoiceExpressionType).p.expr as LiteralExpressionType).text == "test"
	assert (p.bindings["*"].expr.expr as ChoiceExpressionType).p.min == 0
	assert (p.bindings["*"].expr.expr as ChoiceExpressionType).p.max == -1

	assert (p.bindings["*"].expr.expr as ChoiceExpressionType).q.expr is ChoiceExpressionType
	assert ((p.bindings["*"].expr.expr as ChoiceExpressionType).q.expr as ChoiceExpressionType).p.expr is NegativeLookAheadExpressionType
	assert (((p.bindings["*"].expr.expr as ChoiceExpressionType).q.expr as ChoiceExpressionType).p.expr as NegativeLookAheadExpressionType).p.expr is LiteralExpressionType
	assert ((((p.bindings["*"].expr.expr as ChoiceExpressionType).q.expr as ChoiceExpressionType).p.expr as NegativeLookAheadExpressionType).p.expr as LiteralExpressionType).text == "abc"

	assert (((p.bindings["*"].expr.expr as ChoiceExpressionType).q.expr as ChoiceExpressionType).q.expr as LiteralExpressionType).text == "1"
}
