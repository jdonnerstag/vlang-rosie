module parser

import rosie.runtime as rt

fn test_pattern_elem() ? {
	assert LiteralPattern{ text: "aaa" }.repr() == '"aaa"'
	assert CharsetPattern{ cs: rt.new_charset_with_chars("a") }.repr() == "[(97)]"
	assert NamePattern{ text: "cs2" }.repr() == "cs2"

	assert GroupPattern{}.repr() == "()"
	assert GroupPattern{ ar: [Pattern{ elem: NamePattern{ text: "name" }}] }.repr() == "(name)"
	assert GroupPattern{ ar: [
		Pattern{ elem: NamePattern{ text: "name" }, min: 0, max: -1}
		Pattern{ elem: LiteralPattern{ text: "abc" }, min: 0, max: 1}
		Pattern{ elem: CharsetPattern{ cs: rt.new_charset_with_chars("a") }, min: 2, max: 4}
	] }.repr() == '(name* "abc"? [(97)]{2,4})'
}
