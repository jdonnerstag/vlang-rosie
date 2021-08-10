module parser

import rosie.runtime as rt

fn test_pattern_elem() ? {
	assert LiteralPattern{ text: "aaa" }.str() == '"aaa"'
	assert CharsetPattern{ cs: rt.new_charset_with_chars("a") }.str() == "[(97)]"
	assert NamePattern{ text: "cs2" }.str() == "cs2"

	assert GroupPattern{}.str() == "()"
	assert GroupPattern{ ar: [Pattern{ elem: NamePattern{ text: "name" }}] }.str() == "(name)"
	assert GroupPattern{ ar: [
		Pattern{ elem: NamePattern{ text: "name" }, min: 0, max: -1}
		Pattern{ elem: LiteralPattern{ text: "abc" }, min: 0, max: 1}
		Pattern{ elem: CharsetPattern{ cs: rt.new_charset_with_chars("a") }, min: 2, max: 4}
	] }.str() == '(name* "abc"? [(97)]{2,4})'
}
