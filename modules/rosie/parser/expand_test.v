module parser


fn test_ci() ? {
	mut p := new_parser(data: 'ci:"a"', debug: 0)?
	p.parse()?
	mut np := p.expand("*")?
	assert np.repr() == '{"a" / "A"}'

	p = new_parser(data: 'ci:"Test"', debug: 0)?
	p.parse()?
	np = p.expand("*")?
	assert np.repr() == '{{"t" / "T"} {"e" / "E"} {"s" / "S"} {"t" / "T"}}'

	p = new_parser(data: 'ci:"+me()"', debug: 0)?
	p.parse()?
	np = p.expand("*")?
	assert np.repr() == '{"+" {"m" / "M"} {"e" / "E"} "(" ")"}'

	p = new_parser(data: '"a" ci:"b" "c"', debug: 0)?
	p.parse()?
	np = p.expand("*")?
	assert np.repr() == '("a" {"b" / "B"} "c")'

	p = new_parser(data: 'find:ci:"a"', debug: 0)?
	p.parse()?
	np = p.expand("*")?
	assert np.repr() == '
grammar
	alias <search> = {!{"a" / "A"} .}*
	<anonymous> = {{"a" / "A"}}
in
	alias find = {<search> <anonymous>}
end
'

	p = new_parser(data: 'ci:find:"a"', debug: 0)?
	p.parse()?
	np = p.expand("*")?
	assert np.repr() == '
grammar
	alias <search> = {!{"a" / "A"} .}*
	<anonymous> = {{"a" / "A"}}
in
	alias find = {<search> <anonymous>}
end
'

	p = new_parser(data: 'alias a = ci:"a"; b = a', debug: 0)?
	p.parse()?
	np = p.expand("a")?
	assert np.repr() == '{"a" / "A"}'
	np = p.expand("b")?
	//assert np.repr() == '{"a" / "A"}'
	assert np.repr() == 'a'

	p = new_parser(data: 'a = ci:"a"; b = a', debug: 0)?
	p.parse()?
	np = p.expand("b")?
	assert np.repr() == 'a'
}

fn test_find() ? {
	mut p := new_parser(data: 'find:".com"', debug: 0)?
	p.parse()?
	np := p.expand("*")?
	assert np.repr() == '
grammar
	alias <search> = {!".com" .}*
	<anonymous> = {".com"}
in
	alias find = {<search> <anonymous>}
end
'
}

fn test_expand_name_with_predicate() ? {
	mut p := new_parser(data: 'alias W = "a"{4}; x = <W', debug: 0)?
	p.parse()?
	mut np := p.expand("W")?
	assert np.repr() == '"a"{4,4}'
	np = p.expand("x")?
	assert np.repr() == '<W'
}
