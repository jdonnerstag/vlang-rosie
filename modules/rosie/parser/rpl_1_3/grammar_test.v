module rpl_1_3

fn test_import() ? {
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

fn test_double_grammar() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: '
grammar
	aaa = "a"
in
	bbb = aaa
end

grammar
	yyy = "x"
in
	xxx = yyy
end
')?

	//p.main.print_bindings()
	assert p.main.get("bbb")?.package == "main"
	assert p.main.get("bbb")?.grammar == "grammar-0"

	assert p.main.get("xxx")?.package == "main"
	assert p.main.get("xxx")?.grammar == "grammar-1"
}
/* */