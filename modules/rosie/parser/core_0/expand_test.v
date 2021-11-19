module core_0


fn test_ci() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: 'ci:"a"')?
	mut np := p.expand("*")?
	assert np.repr() == '[(65)(97)]'

	p = new_parser(debug: 0)?
	p.parse(data: 'ci:"Test"')?
	np = p.expand("*")?
	assert np.repr() == '{[(84)(116)] [(69)(101)] [(83)(115)] [(84)(116)]}'

	p = new_parser(debug: 0)?
	p.parse(data: 'ci:"+me()"')?
	np = p.expand("*")?
	assert np.repr() == '{"+" [(77)(109)] [(69)(101)] "(" ")"}'

	p = new_parser(debug: 0)?
	p.parse(data: '"a" ci:"b" "c"')?
	np = p.expand("*")?
	assert np.repr() == '{"a" ~ [(66)(98)] ~ "c"}'

	p = new_parser(debug: 0)?
	p.parse(data: 'find:ci:"a"')?
	np = p.expand("*")?
	assert np.repr() == '{
grammar
	alias <search> = {![(65)(97)] .}*
	<anonymous> = {[(65)(97)]}
in
	alias find = {<search> <anonymous>}
end
}'

	p = new_parser(debug: 0)?
	p.parse(data: 'ci:find:"a"')?
	np = p.expand("*")?
	assert np.repr() == '{
grammar
	alias <search> = {![(65)(97)] .}*
	<anonymous> = {[(65)(97)]}
in
	alias find = {<search> <anonymous>}
end
}'

	p = new_parser(debug: 0)?
	p.parse(data: 'alias a = ci:"a"; b = a')?
	np = p.expand("a")?
	assert np.repr() == '[(65)(97)]'
	np = p.expand("b")?
	//assert np.repr() == '{"a" / "A"}'
	assert np.repr() == 'a'

	p = new_parser(debug: 0)?
	p.parse(data: 'a = ci:"a"; b = a')?
	np = p.expand("b")?
	assert np.repr() == 'a'
}

fn test_find() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: 'findall:".com"')?
	np := p.expand("*")?
	assert np.repr() == '{
grammar
	alias <search> = {!".com" .}*
	<anonymous> = {".com"}
in
	alias find = {<search> <anonymous>}
end
}+'
}

fn test_expand_name_with_predicate() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: 'alias W = "a"{4}; x = <W')?
	mut np := p.expand("W")?
	assert np.repr() == '"a"{4,4}'
	np = p.expand("x")?
	assert np.repr() == '<W'
}

fn test_expand_tok() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: '("a")')?
	mut np := p.expand("*")?
	assert np.repr() == '{"a"}'

	p = new_parser(debug: 0)?
	p.parse(data: '("a")?')?
	assert p.pattern_str("*") == 'tok:{"a"}?'
	np = p.expand("*")?
	assert np.repr() == '{"a"}?'

	p = new_parser(debug: 0)?
	p.parse(data: '("a")+')?
	np = p.expand("*")?
	assert np.repr() == '{{"a"} {~ {"a"}}*}'

	p = new_parser(debug: 0)?
	p.parse(data: '("a")*')?
	np = p.expand("*")?
	assert np.repr() == '{{"a"} {~ {"a"}}*}?'

	p = new_parser(debug: 0)?
	p.parse(data: '("a"){0,4}')?
	np = p.expand("*")?
	assert np.repr() == '{{"a"} {~ {"a"}}{0,3}}?'

	p = new_parser(debug: 0)?
	p.parse(data: '("a"){1,4}')?
	np = p.expand("*")?
	assert np.repr() == '{{"a"} {~ {"a"}}{0,3}}'
}

fn test_expand_or() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: 'or:{"a"}')?
	mut np := p.expand("*")?
	assert np.repr() == '"a"'

	p = new_parser(debug: 0)?
	p.parse(data: 'or:{"a"}?')?
	np = p.expand("*")?
	assert np.repr() == '"a"?'

	p = new_parser(debug: 0)?
	p.parse(data: 'or:{"a" "b"}')?
	np = p.expand("*")?
	assert np.repr() == '["a" "b"]'

	p = new_parser(debug: 0)?
	p.parse(data: 'or:{"a" "b"}*')?
	np = p.expand("*")?
	assert np.repr() == '["a" "b"]*'
}
