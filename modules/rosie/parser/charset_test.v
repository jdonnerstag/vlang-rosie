module parser

import rosie.runtime_v2 as rt

fn test_parse_charset_token() ? {
	mut p := new_parser(data: '[]', debug: 0)?
	p.parse()?
	assert p.pattern_str("*") == '[]'
	assert p.pattern("*")?.elem is CharsetPattern

	p = new_parser(data: '[:digit:]', debug: 0)?
	p.parse()?
	assert p.pattern_str("*") == '[(48-57)]'
	assert p.pattern("*")?.elem is CharsetPattern

	p = new_parser(data: '[:^digit:]', debug: 0)?
	p.parse()?
	assert p.pattern_str("*") == '[(0-47)(58-255)]'
	assert p.pattern("*")?.elem is CharsetPattern

	p = new_parser(data: '[a-z]', debug: 0)?
	p.parse()?
	assert p.pattern_str("*") == '[(97-122)]'
	assert p.pattern("*")?.elem is CharsetPattern

	p = new_parser(data: '[^a-z]', debug: 0)?
	p.parse()?
	assert p.pattern_str("*") == '[(0-96)(123-255)]'
	assert p.pattern("*")?.elem is CharsetPattern

	p = new_parser(data: '[abcdef]', debug: 0)?
	p.parse()?
	assert p.pattern_str("*") == '[(97-102)]'
	assert p.pattern("*")?.elem is CharsetPattern

	p = new_parser(data: '[a-f]', debug: 0)?
	p.parse()?
	assert p.pattern_str("*") == '[(97-102)]'
	assert p.pattern("*")?.elem is CharsetPattern

	p = new_parser(data: '[^abcdef]', debug: 0)?
	p.parse()?
	assert p.pattern_str("*") == '[(0-96)(103-255)]'
	assert p.pattern("*")?.elem is CharsetPattern

	p = new_parser(data: r'[\x00-\x1f]', debug: 0)?
	p.parse()?
	assert p.pattern_str("*") == '[(0-31)]'
	assert p.pattern("*")?.elem is CharsetPattern
}

fn test_charset_open_bracket() ? {
	mut p := new_parser(data: '[[:digit:][a-f]]', debug: 0)?
	p.parse()?
	assert p.pattern_str("*") == '[(48-57)(97-102)]'

	p = new_parser(data: '[[:digit:][abcdef]]', debug: 0)?
	p.parse()?
	assert p.pattern_str("*") == '[(48-57)(97-102)]'

	p = new_parser(data: '[^[:digit:][a-f]]', debug: 0)?
	p.parse()?
	assert p.pattern_str("*") == '[(0-47)(58-96)(103-255)]'

	p = new_parser(data: '[[:digit:] cs2]', debug: 0)?
	p.add_charset_binding("cs2", rt.new_charset_with_chars("a"))
	p.parse()?
	assert p.pattern_str("*") == '[[(48-57)] cs2]'	// TODO Name resolution will happen later

	p = new_parser(data: '[[:space:]]', debug: 0)?
	p.parse()?
	assert p.pattern_str("*") == '[(9-13)(32)]'

	p = new_parser(data: '[[:space:] $]', debug: 0)?
	p.parse()?
	assert p.pattern_str("*") == '[[(9-13)(32)] $]'

	p = new_parser(data: '[[ab] & [a]]', debug: 0)?
	p.parse()?
	assert p.pattern_str("*") == '{[(97-98)] [(97)]}'	// TODO see wrong implementation of "&"

	p = new_parser(data: '[[ab] & !"b"]', debug: 0)?
	p.parse()?
	assert p.pattern_str("*") == '{[(97-98)] !"b"}'		// TODO see wrong implementation of "&"
}
/*
fn test_parse_utf() ? {
	assert ascii.repr() == "[(0-127)]"
	//eprintln(utf8_pat)

	mut p := new_parser(data: r'[\x00-\x7f]', debug: 0)?
	assert p.last_token == .charset
	mut cs := p.parse_charset_token()?
	assert cs.repr() == "[(0-127)]"
}

fn test_escape() ? {
	data := r'[\\]'
	assert data.bytes() == [byte(`[`), `\\`, `\\`, `]`]
	mut p := new_parser(data: data, debug: 0)?
	assert p.last_token == .charset
	mut cs := p.parse_charset_token()?
	assert cs.repr() == "[(92)]"
}

fn test_plus_minus() ? {
	data := r'[+\-]'
	assert data.bytes() == [byte(`[`), `+`, `\\`, `-`, `]`]
	mut p := new_parser(data: data, debug: 0)?
	assert p.last_token == .charset
	mut cs := p.parse_charset_token()?
	assert cs.repr() == "[(43)(45)]"
}