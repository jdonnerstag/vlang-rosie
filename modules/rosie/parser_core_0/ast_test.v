module parser_core_0

import rosie.runtime_v2 as rt

fn test_pattern_elem() ? {
	assert LiteralPattern{ text: "aaa" }.repr() == '"aaa"'
	assert CharsetPattern{ cs: rt.new_charset_from_rpl("a") }.repr() == "[(97)]"
	assert NamePattern{ name: "cs2" }.repr() == "cs2"

	assert GroupPattern{}.repr() == "{}"
	assert GroupPattern{ ar: [Pattern{ elem: NamePattern{ name: "name" }}] }.repr() == "{name}"
	assert GroupPattern{ ar: [
		Pattern{ elem: NamePattern{ name: "name" }, min: 0, max: -1}
		Pattern{ elem: LiteralPattern{ text: "abc" }, min: 0, max: 1}
		Pattern{ elem: CharsetPattern{ cs: rt.new_charset_from_rpl("a") }, min: 2, max: 4}
	] }.repr() == '{name* "abc"? [(97)]{2,4}}'
}

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