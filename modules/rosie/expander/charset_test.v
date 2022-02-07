module expander

import rosie
import rosie.expander
import rosie.parser.stage_0 as parser


fn parse_and_expand(rpl string, name string, debug int) ? parser.Parser {
	mut p := parser.new_parser(debug: debug)?
	p.parse(data: rpl)?

	mut e := expander.new_expander(main: p.main, debug: p.debug, unit_test: false)
	e.expand(name)?

	return p
}


fn test_parse_charset_token() ? {
	mut p := parse_and_expand('[]', "*", 0)?
	assert p.pattern_str("*") == '[]'
	assert p.pattern("*")?.elem is rosie.CharsetPattern

	p = parse_and_expand('[:digit:]', "*", 0)?
	assert p.pattern_str("*") == '[(48-57)]'
	assert p.pattern("*")?.elem is rosie.CharsetPattern

	p = parse_and_expand('[:^digit:]', "*", 0)?
	assert p.pattern_str("*") == '[(0-47)(58-255)]'
	assert p.pattern("*")?.elem is rosie.CharsetPattern

	p = parse_and_expand('[a-z]', "*", 0)?
	assert p.pattern_str("*") == '[(97-122)]'
	assert p.pattern("*")?.elem is rosie.CharsetPattern

	p = parse_and_expand('[^a-z]', "*", 0)?
	assert p.pattern_str("*") == '[(0-96)(123-255)]'
	assert p.pattern("*")?.elem is rosie.CharsetPattern

	p = parse_and_expand('[abcdef]', "*", 0)?
	assert p.pattern_str("*") == '[(97-102)]'
	assert p.pattern("*")?.elem is rosie.CharsetPattern

	p = parse_and_expand('[a-f]', "*", 0)?
	assert p.pattern_str("*") == '[(97-102)]'
	assert p.pattern("*")?.elem is rosie.CharsetPattern

	p = parse_and_expand('[^abcdef]', "*", 0)?
	assert p.pattern_str("*") == '[(0-96)(103-255)]'
	assert p.pattern("*")?.elem is rosie.CharsetPattern

	p = parse_and_expand(r'[\x00-\x1f]', "*", 0)?
	assert p.pattern_str("*") == '[(0-31)]'
	assert p.pattern("*")?.elem is rosie.CharsetPattern
}

fn test_charset_open_bracket() ? {
	mut p := parse_and_expand('[[:digit:][a-f]]', "*", 0)?
	assert p.pattern_str("*") == '[(48-57)(97-102)]'

	p = parse_and_expand('[[:digit:][abcdef]]', "*", 0)?
	assert p.pattern_str("*") == '[(48-57)(97-102)]'

	p = parse_and_expand('[^[:digit:][a-f]]', "*", 0)?
	assert p.pattern_str("*") == '[(0-47)(58-96)(103-255)]'

	p = parser.new_parser()?
	p.add_charset_binding("cs2", rosie.new_charset_from_rpl("a"))
	p.parse(data: '[[:digit:] cs2]')?
	mut e := expander.new_expander(main: p.main, debug: p.debug, unit_test: false)
	e.expand("*")?
	assert p.pattern_str("*") == '[[(48-57)] cs2]'

	p = parse_and_expand('[[:space:]]', "*", 0)?
	assert p.pattern_str("*") == '[(9-13)(32)]'

	p = parse_and_expand('[[:space:] $]', "*", 0)?
	assert p.pattern_str("*") == '[[(9-13)(32)] $]'

	p = parse_and_expand('[[ab] & [a]]', "*", 0)?
	//assert p.pattern_str("*") == '[{>[ab] [a]}]'		// TODO '&' is very rarely used

	p = parse_and_expand('[[ab] & !"b"]', "*", 0)?
	//assert p.pattern_str("*") == '{>[(97-98)] !"b"}'	// TODO '&' is very rarely used
}

fn test_parse_utf() ? {
	assert rosie.ascii.repr() == "[(0-127)]"
	//eprintln(utf8_pat)

	mut p := parse_and_expand(r'[\x00-\x7f]', "*", 0)?
	assert p.pattern_str("*") == '[(0-127)]'
}

fn test_escape() ? {
	mut p := parse_and_expand(r'[\\]', "*", 0)?
	assert p.pattern_str("*") == '"\\"'
}

fn test_plus_minus() ? {
	mut p := parse_and_expand(r'[+\-]', "*", 0)?
	assert p.pattern_str("*") == "[(43)(45)]"
}
/* */
