module parser_core_0

fn test_find() ? {
	mut p := new_parser(data: 'find:".com"', debug: 0)?
	p.parse()?
	//eprintln(p.pattern("*")?)
	assert p.pattern("*")?.min == 1
	assert p.pattern("*")?.max == 1
	assert p.pattern_str("*") == 'find:".com"'
	assert p.pattern("*")?.elem is MacroPattern

	p = new_parser(data: 'find:{[:^space:]+ <".com"}', debug: 0)?
	p.parse()?
	//eprintln(p.pattern("*")?)
	assert p.pattern("*")?.min == 1
	assert p.pattern("*")?.max == 1
	assert p.pattern_str("*") == 'find:{[(0-8)(14-31)(33-255)]+ <".com"}'
	assert p.pattern("*")?.elem is MacroPattern
}

fn test_findall_ci() ? {
	mut p := new_parser(data: 'findall:ci:"test"', debug: 0)?
	p.parse()?
	//eprintln(p.pattern("*")?)
	assert p.pattern("*")?.min == 1
	assert p.pattern("*")?.max == 1
	assert p.pattern_str("*") == 'findall:ci:"test"'
	assert p.pattern("*")?.elem is MacroPattern
	assert (p.pattern("*")?.elem as MacroPattern).pat.elem is MacroPattern

	p = new_parser(data: 'findall:ci:{"test" "xx"}', debug: 0)?
	p.parse()?
	assert p.pattern_str("*") == 'findall:ci:{"test" "xx"}'

	p = new_parser(data: 'findall:{ci:"test"}', debug: 0)?
	p.parse()?
	assert p.pattern_str("*") == 'findall:{ci:"test"}'
}
