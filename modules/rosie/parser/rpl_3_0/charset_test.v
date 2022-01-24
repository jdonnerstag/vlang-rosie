module rpl_3_0

import rosie

fn test_parse_charset_token() ? {
	mut p := new_parser()?
	p.parse(data: '[]')?
	assert p.pattern_str("*") == '{[]}'
	assert p.pattern("*")?.at(0)?.elem is rosie.CharsetPattern

	p = new_parser()?
	p.parse(data: '[:digit:]')?
	assert p.pattern_str("*") == '{[(48-57)]}'
	assert p.pattern("*")?.at(0)?.elem is rosie.CharsetPattern

	p = new_parser(debug: 0)?
	p.parse(data: '[^:digit:]')?
	assert p.pattern_str("*") == '{[(0-47)(58-255)]}'
	assert p.pattern("*")?.at(0)?.elem is rosie.CharsetPattern

	p = new_parser()?
	p.parse(data: '[a-z]')?
	assert p.pattern_str("*") == '{[(97-122)]}'
	assert p.pattern("*")?.at(0)?.elem is rosie.CharsetPattern

	p = new_parser()?
	p.parse(data: '[^a-z]')?
	assert p.pattern_str("*") == '{[(0-96)(123-255)]}'
	assert p.pattern("*")?.at(0)?.elem is rosie.CharsetPattern

	p = new_parser()?
	p.parse(data: '[abcdef]')?
	assert p.pattern_str("*") == '{[(97-102)]}'
	assert p.pattern("*")?.at(0)?.elem is rosie.CharsetPattern

	p = new_parser()?
	p.parse(data: '[a-f]')?
	assert p.pattern_str("*") == '{[(97-102)]}'
	assert p.pattern("*")?.at(0)?.elem is rosie.CharsetPattern

	p = new_parser()?
	p.parse(data: '[^abcdef]')?
	assert p.pattern_str("*") == '{[(0-96)(103-255)]}'
	assert p.pattern("*")?.at(0)?.elem is rosie.CharsetPattern

	p = new_parser(debug: 0)?
	p.parse(data: r'[\x00-\x1f]')?
	assert p.pattern_str("*") == '{[(0-31)]}'
	assert p.pattern("*")?.at(0)?.elem is rosie.CharsetPattern
}

fn test_charset_open_bracket() ? {
	mut p := new_parser()?
	p.parse(data: '[[:digit:][a-f]]')?
	assert p.pattern_str("*") == '{[(48-57)(97-102)]}'

	p = new_parser()?
	p.parse(data: '[[:digit:][abcdef]]')?
	assert p.pattern_str("*") == '{[(48-57)(97-102)]}'

	p = new_parser(debug: 0)?
	p.parse(data: '[^[:digit:][a-f]]')?
	assert p.pattern_str("*") == '{[(0-47)(58-96)(103-255)]}'

	p = new_parser(debug: 0)?
	p.add_charset_binding("cs2", rosie.new_charset_from_rpl("a"))
	p.parse(data: '[[:digit:] cs2]')?
	assert p.pattern_str("*") == '{[(48-57)(97)]}'

	p = new_parser()?
	p.parse(data: '[[:space:]]')?
	assert p.pattern_str("*") == '{[(9-13)(32)]}'
/* No longer supported in RPL 3.0
	p = new_parser()?
	p.parse(data: '[[:space:] $]')?  	// [:space:] / $
	assert p.pattern_str("*") == '[[(9-13)(32)] $]'
*/
/* No longer supported in RPL 3.0
	p = new_parser(debug: 0)?
	p.parse(data: '[[ab] & [a]]')?		// Not supported in rpl 3.0
	assert p.pattern_str("*") == '[(97)]'
*/
/* No longer supported in RPL 3.0
	p = new_parser()?
	p.parse(data: '[[ab] & !"b"]')?		// Not supported in rpl 3.0
	assert p.pattern_str("*") == '[(97)]'
*/
}

fn test_parse_utf() ? {
	assert rosie.ascii.repr() == "[(0-127)]"
	//eprintln(utf8_pat)

	mut p := new_parser()?
	p.parse(data: r'[\x00-\x7f]')?
	assert p.pattern_str("*") == '{[(0-127)]}'
}

fn test_escape() ? {
	mut p := new_parser()?
	p.parse(data: r'[\\]')?
	assert p.pattern_str("*") == "{[(92)]}"
}

fn test_plus_minus() ? {
	mut p := new_parser()?
	p.parse(data: r'[+\-]')?
	assert p.pattern_str("*") == "{[(43)(45)]}"
}
/* */
