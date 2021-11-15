module rpl

fn test_find() ? {
	mut p := new_parser(debug: 0)?
	p.parse('find:".com"')?
	//eprintln(p.pattern("*")?)
	assert p.pattern("*")?.min == 1
	assert p.pattern("*")?.max == 1
	assert p.pattern_str("*") == 'find:".com"'
	assert p.pattern("*")?.elem is MacroPattern

	p = new_parser()?
	p.parse('find:{[:^space:]+ <".com"}')?
	//eprintln(p.pattern("*")?)
	assert p.pattern("*")?.min == 1
	assert p.pattern("*")?.max == 1
	assert p.pattern_str("*") == 'find:{[(0-8)(14-31)(33-255)]+ <".com"}'
	assert p.pattern("*")?.elem is MacroPattern
}

fn test_findall_ci() ? {
	mut p := new_parser(debug: 55)?
	p.parse('findall:ci:"test"')?
	//eprintln(p.pattern("*")?)
	assert p.pattern("*")?.min == 1
	assert p.pattern("*")?.max == 1
	assert p.pattern_str("*") == 'findall:ci:"test"'
	assert p.pattern("*")?.elem is MacroPattern
	assert (p.pattern("*")?.elem as MacroPattern).pat.elem is MacroPattern

	p = new_parser()?
	p.parse('findall:ci:{"test" "xx"}')?
	assert p.pattern_str("*") == 'findall:ci:{"test" "xx"}'

	p = new_parser()?
	p.parse('findall:{ci:"test"}')?
	assert p.pattern_str("*") == 'findall:ci:"test"'
}
