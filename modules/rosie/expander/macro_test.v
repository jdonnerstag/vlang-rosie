module expander

import rosie
import rosie.expander
import rosie.parser.stage_0 as parser

fn str_normalize(a string, from int, len int) string {
	mut str := a[from..]
	if str.len > len { str = str[..len] + " .."}
	str = str.replace("\n", "\\n").replace("\r", "\\r")
	return str
}

// TODO May be add to some of assert-lib
fn assert_string(str1 string, str2 string) ? {
	for i in 0 .. str1.len {
		if i >= str2.len {
			mut str := str_normalize(str2, i, 25)
			return error("assert error: str1.len > str2.len; '$str'")
		} else if str1[i] != str2[i] {
			mut str_a := str_normalize(str1, i, 25)
			mut str_b := str_normalize(str2, i, 25)
			return error("assert error: pos=$i; '$str_a' != '$str_b', '$str1'")
		}
	}

	if str2.len > str1.len {
		mut str := str_normalize(str2, str1.len, 25)
		return error("assert error ... str2.len > str1.len; '$str'")
	}
}

fn parse_and_expand(rpl string, name string, debug int) ? parser.Parser {
	mut p := parser.new_parser(debug: debug)?
	p.parse(data: rpl)?

	mut e := expander.new_expander(main: p.main, debug: p.debug, unit_test: false)
	e.expand(name)?

	return p
}

fn test_find() ? {
	mut p := parse_and_expand('find:".com"', "*", 0)?
	//eprintln(p.pattern("*")?)
	assert p.pattern("*")?.min == 1
	assert p.pattern("*")?.max == 1
	assert_string(p.pattern_str("*"), '{
grammar
	alias <search> = {!".com" .}*
	<anonymous> = {".com"}
in
	alias find = {<search> <anonymous>}
end
}')?

	p = parse_and_expand('find:{[:^space:]+ <".com"}', "*", 0)?
	//eprintln(p.pattern("*")?)
	assert p.pattern("*")?.min == 1
	assert p.pattern("*")?.max == 1
	assert_string(p.pattern_str("*"), '{
grammar
	alias <search> = {!{[(0-8)(14-31)(33-255)]+ <".com"} .}*
	<anonymous> = {{[(0-8)(14-31)(33-255)]+ <".com"}}
in
	alias find = {<search> <anonymous>}
end
}')?
}

fn test_findall_ci() ? {
	mut p := parse_and_expand('findall:ci:"test"', "*", 0)?
	//eprintln(p.pattern("*")?)
	assert_string(p.pattern_str("*"), '{
grammar
	alias <search> = {!{[(84)(116)] [(69)(101)] [(83)(115)] [(84)(116)]} .}*
	<anonymous> = {{[(84)(116)] [(69)(101)] [(83)(115)] [(84)(116)]}}
in
	alias find = {<search> <anonymous>}
end
}+')?

	p = parse_and_expand('findall:ci:{"test" "xx"}', "*", 0)?
	assert_string(p.pattern_str("*"), '{
grammar
	alias <search> = {!{{[(84)(116)] [(69)(101)] [(83)(115)] [(84)(116)]} {[(88)(120)] [(88)(120)]}} .}*
	<anonymous> = {{{[(84)(116)] [(69)(101)] [(83)(115)] [(84)(116)]} {[(88)(120)] [(88)(120)]}}}
in
	alias find = {<search> <anonymous>}
end
}+')?

	p = parse_and_expand('findall:{ci:"test"}', "*", 0)?
	assert_string(p.pattern_str("*"), '{
grammar
	alias <search> = {!{{[(84)(116)] [(69)(101)] [(83)(115)] [(84)(116)]}} .}*
	<anonymous> = {{{[(84)(116)] [(69)(101)] [(83)(115)] [(84)(116)]}}}
in
	alias find = {<search> <anonymous>}
end
}+')?
}

fn test_macro() ? {
	mut p := parse_and_expand('x = "x"; foo_1:x', "*", 0)?
	assert_string(p.pattern_str("*"), 'foo_1:x')?
}
