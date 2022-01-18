module core_0

fn test_grammar_block() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: '
grammar
	yyy = "a"
in
	xxx = yyy
end
')?

	//p.main.print_bindings()
	assert p.main.get("xxx")?.package == "main"
	assert p.main.get("xxx")?.grammar == "grammar-0"
	assert p.main.get("grammar-0.yyy")?.package == "grammar-0"
	assert p.main.get("grammar-0.yyy")?.grammar == ""
}

fn test_grammar_stmt() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: '
grammar
	yyy = "a"
end
')?

	//p.main.print_bindings()
	assert p.main.get("yyy")?.package == "main"
	assert p.main.get("yyy")?.grammar == "grammar-0"
}
/* */