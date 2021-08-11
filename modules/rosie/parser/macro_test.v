module parser

fn test_find() ? {
	mut p := new_parser(data: 'find:".com"', debug: 99)?
	p.parse_binding()?
	//eprintln(p.binding("*")?)
	assert p.binding("*")?.min == 1
	assert p.binding("*")?.max == 1
	assert p.binding_str("*") == 'find:".com"'
	assert p.binding("*")?.elem is MacroPattern

	p = new_parser(data: 'find:{[:^space:]+ <".com"}', debug: 0)?
	p.parse_binding()?
	//eprintln(p.binding("*")?)
	assert p.binding("*")?.min == 1
	assert p.binding("*")?.max == 1
	assert p.binding_str("*") == 'find:{[(0-8)(14-31)(33-255)]+ <".com"}'
	assert p.binding("*")?.elem is MacroPattern
}

fn test_findall_ci() ? {
	mut p := new_parser(data: 'findall:ci:"test"', debug: 0)?
	p.parse_binding()?
	//eprintln(p.binding("*")?)
	assert p.binding("*")?.min == 1
	assert p.binding("*")?.max == 1
	assert p.binding_str("*") == 'findall:ci:"test"'
	assert p.binding("*")?.elem is MacroPattern
	assert (p.binding("*")?.elem as MacroPattern).pat.elem is MacroPattern
}
