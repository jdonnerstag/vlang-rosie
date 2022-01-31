module core_0

fn test_input_len() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: '{[a] [b]}')?
	assert p.binding("*")?.pattern.repr() == '{[(97)] [(98)]}'
	assert p.binding("*")?.pattern.input_len()? == 2

	p = new_parser(debug: 0)?
	p.parse(data: '{![a] [b]}')?
	assert p.binding("*")?.pattern.repr() == '{![(97)] [(98)]}'
	assert p.binding("*")?.pattern.input_len()? == 1

	p = new_parser(debug: 0)?
	p.parse(data: '<{[a] [b]}')?
	assert p.binding("*")?.pattern.repr() == '<{[(97)] [(98)]}'
	assert p.binding("*")?.pattern.input_len()? == 0

	p = new_parser(debug: 0)?
	p.parse(data: '"a"')?
	assert p.binding("*")?.pattern.repr() == '"a"'
	assert p.binding("*")?.pattern.input_len()? == 1

	p = new_parser(debug: 0)?
	p.parse(data: '"a" "b"')?
	assert p.binding("*")?.pattern.repr() == '("a" "b")'
	if _ := p.binding("*")?.pattern.input_len() { assert false }

	p = new_parser(debug: 0)?
	p.parse(data: '{"a" "b"}')?
	assert p.binding("*")?.pattern.repr() == '{"a" "b"}'
	assert p.binding("*")?.pattern.input_len()? == 2
/*
	p = new_parser(debug: 0)?
	p.parse(data: '["a" "b"]')?		// TODO Not yet supported with stage_0 parser
	assert p.binding("*")?.pattern.repr() == '[(97-98)]'
	assert p.binding("*")?.pattern.input_len()? == 1
*/
	p = new_parser(debug: 0)?
	p.parse(data: '[[a] [b]]')?
	assert p.binding("*")?.pattern.repr() == '[(97-98)]'
	assert p.binding("*")?.pattern.input_len()? == 1

	p = new_parser(debug: 0)?
	p.parse(data: '("a" / "b")')?
	assert p.binding("*")?.pattern.repr() == '["a" "b"]'
	assert p.binding("*")?.pattern.input_len()? == 1
}