module core_0

fn test_input_len() ? {
	mut p := new_parser(data: '{[a] [b]}', debug: 0)?
	p.parse()?
	assert p.binding("*")?.pattern.repr() == '{[(97)] [(98)]}'
	assert p.binding("*")?.pattern.input_len()? == 2

	p = new_parser(data: '{![a] [b]}', debug: 0)?
	p.parse()?
	assert p.binding("*")?.pattern.repr() == '{![(97)] [(98)]}'
	assert p.binding("*")?.pattern.input_len()? == 1

	p = new_parser(data: '<{[a] [b]}', debug: 0)?
	p.parse()?
	assert p.binding("*")?.pattern.repr() == '<{[(97)] [(98)]}'
	assert p.binding("*")?.pattern.input_len()? == 0
}