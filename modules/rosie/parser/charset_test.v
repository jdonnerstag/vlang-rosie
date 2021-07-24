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
	assert cs.str() == "[(49-57)]"

	p = new_parser(data: '[:^digit:]', debug: 0)?
	assert p.last_token == .charset
	cs = p.parse_charset()?
	assert cs.str() == "[(1-48)(58-255)]"

	p = new_parser(data: '[a-z]', debug: 0)?
	assert p.last_token == .charset
	cs = p.parse_charset()?
	assert cs.str() == "[(98-123)]"

	p = new_parser(data: '[^a-z]', debug: 0)?
	assert p.last_token == .charset
	cs = p.parse_charset()?
	assert cs.str() == "[(1-97)(124-255)]"

	p = new_parser(data: '[abcdef]', debug: 0)?
	assert p.last_token == .charset
	cs = p.parse_charset()?
	assert cs.str() == "[(98-103)]"

	p = new_parser(data: '[a-f]', debug: 0)?
	assert p.last_token == .charset
	cs = p.parse_charset()?
	assert cs.str() == "[(98-103)]"

	p = new_parser(data: '[^abcdef]', debug: 0)?
	assert p.last_token == .charset
	cs = p.parse_charset()?
	assert cs.str() == "[(1-97)(104-255)]"

	p = new_parser(data: r'[\x00-\x1f]', debug: 0)?
	assert p.last_token == .charset
	cs = p.parse_charset()?
	assert cs.str() == "[(1-32)]"
}

fn test_charset_open_bracket() ? {
	mut p := new_parser(data: '[[:digit:][a-f]]', debug: 0)?
	assert p.last_token == .open_bracket
	mut cs := p.parse_charset()?
	assert cs.str() == "[(49-57)(98-103)]"

	p = new_parser(data: '[[:digit:][abcdef]]', debug: 0)?
	assert p.last_token == .open_bracket
	cs = p.parse_charset()?
	assert cs.str() == "[(49-57)(98-103)]"

	p = new_parser(data: '[^[:digit:][a-f]]', debug: 0)?
	assert p.last_token == .open_bracket
	cs = p.parse_charset()?
	assert cs.str() == "[(1-48)(58-97)(104-255)]"

	p = new_parser(data: '[[:digit:] cs2]', debug: 0)?
	assert p.last_token == .open_bracket
	p.add_charset_binding("cs2", rt.new_charset_with_chars("a"))
	cs = p.parse_charset()?
	assert cs.str() == "[(49-57)(98)]"

	p = new_parser(data: '[[:space:]]', debug: 0)?
	assert p.last_token == .open_bracket
	cs = p.parse_charset()?
	assert cs.str() == "[(10-14)(33)]"

	p = new_parser(data: '[[:space:] $]', debug: 99)?
	assert p.last_token == .open_bracket
	cs = p.parse_charset()?
	assert cs.str() == "[(10-14)(33)]"

	p = new_parser(data: '[[ab] & [a]]', debug: 0)?
	assert p.last_token == .open_bracket
	cs = p.parse_charset()?
	assert cs.str() == "[(98)]"

	p = new_parser(data: '[[ab] & !"b"]', debug: 0)?
	assert p.last_token == .open_bracket
	cs = p.parse_charset()?
	assert cs.str() == "[(98)]"
}
