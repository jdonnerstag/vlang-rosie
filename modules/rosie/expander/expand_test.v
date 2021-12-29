
import rosie.expander
import rosie.parser.core_0 as parser

fn test_ci() ? {
	mut p := parser.new_parser(debug: 0)?
	p.parse(data: 'ci:"a"')?
	mut e := expander.new_expander(main: p.main, debug: 0)
	mut np := e.expand("*")?
	assert np.repr() == '[(65)(97)]'

	p = parser.new_parser(debug: 0)?
	p.parse(data: 'ci:"Test"')?
	e = expander.new_expander(main: p.main, debug: 0)
	np = e.expand("*")?
	assert np.repr() == '{[(84)(116)] [(69)(101)] [(83)(115)] [(84)(116)]}'

	p = parser.new_parser(debug: 0)?
	p.parse(data: 'ci:"+me()"')?
	e = expander.new_expander(main: p.main, debug: 0)
	np = e.expand("*")?
	assert np.repr() == '{"+" [(77)(109)] [(69)(101)] "(" ")"}'

	p = parser.new_parser(debug: 0)?
	p.parse(data: '"a" ci:"b" "c"')?
	e = expander.new_expander(main: p.main, debug: 0)
	np = e.expand("*")?
	assert np.repr() == '{"a" ~ [(66)(98)] ~ "c"}'

	p = parser.new_parser(debug: 0)?
	p.parse(data: 'find:ci:"a"')?
	e = expander.new_expander(main: p.main, debug: 0)
	np = e.expand("*")?
	assert np.repr() == '{
grammar
	alias <search> = {![(65)(97)] .}*
	<anonymous> = {[(65)(97)]}
in
	alias find = {<search> <anonymous>}
end
}'

	p = parser.new_parser(debug: 0)?
	p.parse(data: 'ci:find:"a"')?
	e = expander.new_expander(main: p.main, debug: 0)
	np = e.expand("*")?
	assert np.repr() == '{
grammar
	alias <search> = {![(65)(97)] .}*
	<anonymous> = {[(65)(97)]}
in
	alias find = {<search> <anonymous>}
end
}'

	p = parser.new_parser(debug: 0)?
	p.parse(data: 'alias a = ci:"a"; b = a')?
	e = expander.new_expander(main: p.main, debug: 0)
	np = e.expand("a")?
	assert np.repr() == '[(65)(97)]'
	np = e.expand("b")?
	//assert np.repr() == '{"a" / "A"}'
	assert np.repr() == 'a'

	p = parser.new_parser(debug: 0)?
	p.parse(data: 'a = ci:"a"; b = a')?
	e = expander.new_expander(main: p.main, debug: 0)
	np = e.expand("b")?
	assert np.repr() == 'a'
}

fn test_find() ? {
	mut p := parser.new_parser(debug: 0)?
	p.parse(data: 'findall:".com"')?
	mut e := expander.new_expander(main: p.main, debug: 0)
	np := e.expand("*")?
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
	mut p := parser.new_parser(debug: 0)?
	p.parse(data: 'alias W = "a"{4}; x = <W')?
	mut e := expander.new_expander(main: p.main, debug: 0)
	mut np := e.expand("W")?
	assert np.repr() == '"a"{4,4}'
	np = e.expand("x")?
	assert np.repr() == '<W'
}

fn test_expand_tok() ? {
	mut p := parser.new_parser(debug: 0)?
	p.parse(data: '("a")')?
	mut e := expander.new_expander(main: p.main, debug: 0)
	mut np := e.expand("*")?
	assert np.repr() == '{"a"}'

	p = parser.new_parser(debug: 0)?
	p.parse(data: '("a")?')?
	assert p.pattern_str("*") == 'tok:{"a"}?'
	e = expander.new_expander(main: p.main, debug: 0)
	np = e.expand("*")?
	assert np.repr() == '{"a"}?'

	p = parser.new_parser(debug: 0)?
	p.parse(data: '("a")+')?
	e = expander.new_expander(main: p.main, debug: 0)
	np = e.expand("*")?
	assert np.repr() == '{{"a"} {~ {"a"}}*}'

	p = parser.new_parser(debug: 0)?
	p.parse(data: '("a")*')?
	e = expander.new_expander(main: p.main, debug: 0)
	np = e.expand("*")?
	assert np.repr() == '{{"a"} {~ {"a"}}*}?'

	p = parser.new_parser(debug: 0)?
	p.parse(data: '("a"){0,4}')?
	e = expander.new_expander(main: p.main, debug: 0)
	np = e.expand("*")?
	assert np.repr() == '{{"a"} {~ {"a"}}{0,3}}?'

	p = parser.new_parser(debug: 0)?
	p.parse(data: '("a"){1,4}')?
	e = expander.new_expander(main: p.main, debug: 0)
	np = e.expand("*")?
	assert np.repr() == '{{"a"} {~ {"a"}}{0,3}}'
}

fn test_expand_or() ? {
	mut p := parser.new_parser(debug: 0)?
	p.parse(data: 'or:{"a"}')?
	mut e := expander.new_expander(main: p.main, debug: 0)
	mut np := e.expand("*")?
	assert np.repr() == '"a"'

	p = parser.new_parser(debug: 0)?
	p.parse(data: 'or:{"a"}?')?
	e = expander.new_expander(main: p.main, debug: 0)
	np = e.expand("*")?
	assert np.repr() == '"a"?'

	p = parser.new_parser(debug: 0)?
	p.parse(data: 'or:{"a" "b"}')?
	e = expander.new_expander(main: p.main, debug: 0)
	np = e.expand("*")?
	assert np.repr() == '["a" "b"]'

	p = parser.new_parser(debug: 0)?
	p.parse(data: 'or:{"a" "b"}*')?
	e = expander.new_expander(main: p.main, debug: 0)
	np = e.expand("*")?
	assert np.repr() == '["a" "b"]*'
}
