module rpl

import rosie.runtime_v2 as rt

fn test_parse_charset_token() ? {
	mut p := new_parser()?
	p.parse('[]')?
	assert p.pattern_str("*") == '[]'
	assert p.pattern("*")?.elem is CharsetPattern

	p = new_parser()?
	p.parse('[:digit:]')?
	assert p.pattern_str("*") == '[(48-57)]'
	assert p.pattern("*")?.elem is CharsetPattern

	p = new_parser()?
	p.parse('[:^digit:]')?
	assert p.pattern_str("*") == '[(0-47)(58-255)]'
	assert p.pattern("*")?.elem is CharsetPattern

	p = new_parser()?
	p.parse('[a-z]')?
	assert p.pattern_str("*") == '[(97-122)]'
	assert p.pattern("*")?.elem is CharsetPattern

	p = new_parser()?
	p.parse('[^a-z]')?
	assert p.pattern_str("*") == '[(0-96)(123-255)]'
	assert p.pattern("*")?.elem is CharsetPattern

	p = new_parser()?
	p.parse('[abcdef]')?
	assert p.pattern_str("*") == '[(97-102)]'
	assert p.pattern("*")?.elem is CharsetPattern

	p = new_parser()?
	p.parse('[a-f]')?
	assert p.pattern_str("*") == '[(97-102)]'
	assert p.pattern("*")?.elem is CharsetPattern

	p = new_parser()?
	p.parse('[^abcdef]')?
	assert p.pattern_str("*") == '[(0-96)(103-255)]'
	assert p.pattern("*")?.elem is CharsetPattern

	p = new_parser(debug: 0)?
	p.parse(r'[\x00-\x1f]')?
	assert p.pattern_str("*") == '[(0-31)]'
	assert p.pattern("*")?.elem is CharsetPattern
}

fn test_charset_open_bracket() ? {
	mut p := new_parser()?
	p.parse('[[:digit:][a-f]]')?
	assert p.pattern_str("*") == '[(48-57)(97-102)]'

	p = new_parser()?
	p.parse('[[:digit:][abcdef]]')?
	assert p.pattern_str("*") == '[(48-57)(97-102)]'

	p = new_parser(debug: 0)?
	p.parse('[^[:digit:][a-f]]')?
	assert p.pattern_str("*") == '[(0-47)(58-96)(103-255)]'

	p = new_parser()?
	p.add_charset_binding("cs2", rt.new_charset_from_rpl("a"))
	p.parse('[[:digit:] cs2]')?
	assert p.pattern_str("*") == '[[(48-57)] cs2]'	// TODO Name resolution will happen later

	p = new_parser()?
	p.parse('[[:space:]]')?
	assert p.pattern_str("*") == '[(9-13)(32)]'

	p = new_parser()?
	p.parse('[[:space:] $]')?
	assert p.pattern_str("*") == '[[(9-13)(32)] $]'
/*
  In rpl 1.x the &-operator is equivalent to {>p q}. Which IMHO is misleading, and I've not
  seen it being used anywhere in the lib files. I will not support it.

	p = new_parser(debug: 0)?
	p.parse('[[ab] & [a]]')?
	assert p.pattern_str("*") == '{[(97-98)] [(97)]}'	// TODO see wrong implementation of "&"

	p = new_parser()?
	p.parse('[[ab] & !"b"]')?
	assert p.pattern_str("*") == '{[(97-98)] !"b"}'		// TODO see wrong implementation of "&"
*/
}

fn test_parse_utf() ? {
	assert ascii.repr() == "[(0-127)]"
	//eprintln(utf8_pat)

	mut p := new_parser()?
	p.parse(r'[\x00-\x7f]')?
	assert p.pattern_str("*") == '[(0-127)]'
}

fn test_escape() ? {
	mut p := new_parser()?
	p.parse(r'[\\]')?
	assert p.pattern_str("*") == "[(92)]"
}

fn test_plus_minus() ? {
	mut p := new_parser()?
	p.parse(r'[+\-]')?
	assert p.pattern_str("*") == "[(43)(45)]"
}