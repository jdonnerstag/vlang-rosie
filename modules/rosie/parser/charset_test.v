module parser

import rosie.runtime as rt

fn test_parse_charset_token() ? {
	mut p := new_parser(data: '[]', debug: 0)?
	assert p.last_token == .charset
	mut cs := p.parse_charset()?
	assert cs.str() == "[]"

	p = new_parser(data: '[:digit:]', debug: 0)?
	assert p.last_token == .charset
	cs = p.parse_charset()?
	assert cs.str() == "[(48-57)]"

	p = new_parser(data: '[:^digit:]', debug: 0)?
	assert p.last_token == .charset
	cs = p.parse_charset()?
	assert cs.str() == "[(0-47)(58-255)]"

	p = new_parser(data: '[a-z]', debug: 0)?
	assert p.last_token == .charset
	cs = p.parse_charset()?
	assert cs.str() == "[(97-122)]"

	p = new_parser(data: '[^a-z]', debug: 0)?
	assert p.last_token == .charset
	cs = p.parse_charset()?
	assert cs.str() == "[(0-96)(123-255)]"

	p = new_parser(data: '[abcdef]', debug: 0)?
	assert p.last_token == .charset
	cs = p.parse_charset()?
	assert cs.str() == "[(97-102)]"

	p = new_parser(data: '[a-f]', debug: 0)?
	assert p.last_token == .charset
	cs = p.parse_charset()?
	assert cs.str() == "[(97-102)]"

	p = new_parser(data: '[^abcdef]', debug: 0)?
	assert p.last_token == .charset
	cs = p.parse_charset()?
	assert cs.str() == "[(0-96)(103-255)]"

	p = new_parser(data: r'[\x00-\x1f]', debug: 0)?
	assert p.last_token == .charset
	cs = p.parse_charset()?
	assert cs.str() == "[(0-31)]"
}

fn test_charset_open_bracket() ? {
	mut p := new_parser(data: '[[:digit:][a-f]]', debug: 0)?
	assert p.last_token == .open_bracket
	mut cs := p.parse_charset()?
	assert cs.str() == "[(48-57)(97-102)]"

	p = new_parser(data: '[[:digit:][abcdef]]', debug: 0)?
	assert p.last_token == .open_bracket
	cs = p.parse_charset()?
	assert cs.str() == "[(48-57)(97-102)]"

	p = new_parser(data: '[^[:digit:][a-f]]', debug: 0)?
	assert p.last_token == .open_bracket
	cs = p.parse_charset()?
	assert cs.str() == "[(0-47)(58-96)(103-255)]"

	p = new_parser(data: '[[:digit:] cs2]', debug: 0)?
	assert p.last_token == .open_bracket
	p.add_charset_binding("cs2", rt.new_charset_with_chars("a"))
	cs = p.parse_charset()?
	assert cs.str() == "[(48-57)(97)]"

	p = new_parser(data: '[[:space:]]', debug: 0)?
	assert p.last_token == .open_bracket
	cs = p.parse_charset()?
	assert cs.str() == "[(9-13)(32)]"

	p = new_parser(data: '[[:space:] $]', debug: 0)?
	assert p.last_token == .open_bracket
	cs = p.parse_charset()?
	assert cs.str() == "[(9-13)(32)]"

	p = new_parser(data: '[[ab] & [a]]', debug: 0)?
	assert p.last_token == .open_bracket
	cs = p.parse_charset()?
	assert cs.str() == "[(97)]"

	p = new_parser(data: '[[ab] & !"b"]', debug: 0)?
	assert p.last_token == .open_bracket
	cs = p.parse_charset()?
	assert cs.str() == "[(97)]"
}

fn test_parse_utf() ? {
	assert ascii.str() == "[(0-127)]"
	eprintln(utf8)

	mut p := new_parser(data: r'[\x00-\x7f]', debug: 0)?
	assert p.last_token == .charset
	mut cs := p.parse_charset()?
	assert cs.str() == "[(0-127)]"
}