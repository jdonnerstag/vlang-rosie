
import rosie.parser.rpl_3_0 as parser

fn test_input_len() ? {
	mut p := parser.new_parser(debug: 99)?
	p.parse(data: '([a] [b])')?
	p.main.print_bindings()
	assert p.binding("*")?.pattern.repr() == '{{[(97)] [(98)]}}'	// pattern repr() is in rpl-1.3 format!!
	assert p.binding("*")?.pattern.input_len()? == 2

	p = parser.new_parser(debug: 0)?
	p.parse(data: '[a] [b]')?
	assert p.binding("*")?.pattern.repr() == '{[(97)] [(98)]}'
	assert p.binding("*")?.pattern.input_len()? == 2

	p = parser.new_parser(debug: 0)?
	p.parse(data: '(![a] [b])')?
	assert p.binding("*")?.pattern.repr() == '{{![(97)] [(98)]}}'
	assert p.binding("*")?.pattern.input_len()? == 1

	p = parser.new_parser(debug: 0)?
	p.parse(data: '<([a] [b])')?
	assert p.binding("*")?.pattern.repr() == '{<{[(97)] [(98)]}}'
	assert p.binding("*")?.pattern.input_len()? == 0
}
/* */