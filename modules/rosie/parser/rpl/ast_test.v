
import rosie.parser.rpl as parser
import rosie.engine

fn test_input_len() ? {
	mut p := parser.new_parser(debug: 99)?
	p.parse(data: '{[a] [b]}')?
	//p.package().print_bindings()
	assert p.binding("*")?.pattern.repr() == '{[(97)] [(98)]}'
	assert p.binding("*")?.pattern.input_len()? == 2

	p = parser.new_parser()?
	p.parse(data: '{![a] [b]}')?
	assert p.binding("*")?.pattern.repr() == '{![(97)] [(98)]}'
	assert p.binding("*")?.pattern.input_len()? == 1

	p = parser.new_parser()?
	p.parse(data: '<{[a] [b]}')?
	assert p.binding("*")?.pattern.repr() == '<{[(97)] [(98)]}'
	assert p.binding("*")?.pattern.input_len()? == 0
}

fn test_engine() ? {
	mut rosie := engine.new_engine(debug: 0)?
	rosie.prepare(rpl: '{[a] [b]}')?
	assert rosie.binding("*")?.pattern.repr() == '{"a" "b"}'
	assert rosie.binding("*")?.pattern.input_len()? == 2
}