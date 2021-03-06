
import rosie
import rosie.expander
import rosie.parser.rpl_1_3 as parser


// TODO We need to test the expander with both the core-0 and RPL parsers!!

fn parse_and_expand(rpl string, name string, debug int) ? parser.Parser {
	mut p := parser.new_parser(debug: debug)?
	p.parse(data: rpl)?

	mut e := expander.new_expander(main: p.main, debug: p.debug, unit_test: false)
	e.expand(name)?

	return p
}

fn test_ci() ? {
	mut p := parse_and_expand('ci:"a"', "*", 0)?
	assert p.pattern_str("*") == '[(65)(97)]'

	p = parse_and_expand('ci:"Test"', "*", 0)?
	assert p.pattern_str("*") == '{[(84)(116)] [(69)(101)] [(83)(115)] [(84)(116)]}'

	p = parse_and_expand('ci:"+me()"', "*", 0)?
	assert p.pattern_str("*") == '{"+" [(77)(109)] [(69)(101)] "(" ")"}'

	p = parse_and_expand('"a" ci:"b" "c"', "*", 0)?  // ==
	assert p.pattern_str("*") == '{~ {"a" ~ {[(66)(98)]} ~ "c" ~}}'

	p = parse_and_expand('find:ci:"a"', "*", 0)?
	assert p.pattern_str("*") == '{
grammar
	alias <search> = {!{{[(65)(97)]}} .}*
	<anonymous> = {{{[(65)(97)]}}}
in
	alias find = {<search> <anonymous>}
end
}'

	p = parse_and_expand('ci:find:"a"', "*", 0)?
	assert p.pattern_str("*") == '{
grammar
	alias <search> = {!{[(65)(97)]} .}*
	<anonymous> = {{[(65)(97)]}}
in
	alias find = {<search> <anonymous>}
end
}'

	p = parse_and_expand('alias a = ci:"a"; b = a', "a", 0)?
	assert p.pattern_str("a") == '[(65)(97)]'

	mut e := expander.new_expander(main: p.main, debug: p.debug, unit_test: false)
	e.expand("b")?
	assert p.pattern_str("b") == 'a'

	p = parse_and_expand('a = ci:"a"; b = a', "b", 0)?
	assert p.pattern_str("b") == 'a'
}

fn test_find() ? {
	mut p := parse_and_expand('findall:".com"', "*", 0)?
	assert p.pattern_str("*") == '{
grammar
	alias <search> = {!{".com"} .}*
	<anonymous> = {{".com"}}
in
	alias find = {<search> <anonymous>}
end
}+'
}

fn test_expand_name_with_predicate() ? {
	mut p := parse_and_expand('alias W = "a"{4}; x = <W', "W", 0)?
	mut e := expander.new_expander(main: p.main, debug: p.debug, unit_test: false)
	e.expand("x")?
	assert p.pattern_str("W") == '"a"{4,4}'
	assert p.pattern_str("x") == '<W'

	p = parse_and_expand('alias W = "a"{4}; x = <W{2}', "x", 0)?
	assert p.pattern_str("x") == '<W{2,2}'
}

fn test_expand_tok() ? {
	mut p := parse_and_expand('("a")', "*", 0)?
	assert p.pattern_str("*") == '{~ {"a" ~}}'

	p = parse_and_expand('("a")?', "*", 0)?
	assert p.pattern_str("*") == '{~ {"a" ~}}?'

	p = parse_and_expand('("a")+', "*", 0)?
	assert p.pattern_str("*") == '{~ {"a" ~}+}'

	p = parse_and_expand('("a")*', "*", 0)?
	assert p.pattern_str("*") == '{~ {"a" ~}*}?'

	p = parse_and_expand('("a"){0,4}', "*", 0)?
	assert p.pattern_str("*") == '{~ {"a" ~}{0,4}}?'

	p = parse_and_expand('("a"){1,4}', "*", 0)?
	assert p.pattern_str("*") == '{~ {"a" ~}{1,4}}'
}

fn test_expand_or() ? {
	mut p := parse_and_expand('or:{"a"}', "*", 0)?
	assert p.pattern_str("*") == '"a"'

	p = parse_and_expand('or:{"a"}?', "*", 0)?
	assert p.pattern_str("*") == '["a"]?'

	p = parse_and_expand('or:{"a" "b"}', "*", 0)?
	assert p.pattern_str("*") == '["a" "b"]'		// TODO This could be optimized [ab]

	p = parse_and_expand('or:{"a" "b"}*', "*", 0)?
	assert p.pattern_str("*") == '["a" "b"]*'
}

fn test_charset_combinations() ? {
	mut p := parse_and_expand('[a] / [b] / [c]', "*", 0)?
	assert p.pattern_str("*") == '[(97-99)]'

	p = parse_and_expand('alias a=[a]; alias b=[b]; alias c=[c]; d=a/b/c', "d", 0)?
	assert p.pattern_str("d") == '[a b c]'

	p = parse_and_expand('a=[a]; b=[b]; c=[c]; d=a/b/c', "d", 0)?	// Only optimize if alias
	assert p.pattern_str("d") == '[a b c]'

	p = parse_and_expand(r'alias esc=[\\]; b={!esc !"[" !"]" .}', "b", 0)?
	assert p.pattern_str("b") == r'{!esc !"[" !"]" .}'

	p = parse_and_expand(r'"a" / "b" / "c"', "*", 0)?
	assert p.pattern_str("*") == '[(97-99)]'
}

fn test_charset_identifier()? {
	mut p := parse_and_expand('alias digit = [:digit:]; {[.] digit+}', "*", 0)?
	assert p.pattern_str("*") == '{"." digit+}'
}

fn test_char_rpl() ? {
	mut p := parse_and_expand('import char; x = char.utf8', "x", 0)?
/*
-- test char accepts "\x00", "\x01", "A", "!", "\x7e", "\x7f"
-- test char rejects "", "\x80", "\xff"
-- test X accepts "\x00", "\x01", "A", "!", "\x7e", "\x7f"
-- test X rejects "", "\x80", "\xff"
-- test X accepts "\u2603"                          -- ??? (snowman)
-- test X accepts "\xE2\x98\x83"                    -- ??? (snowman)
*/
	assert p.pattern_str("char.ascii") == '[(0-127)]'
	assert p.pattern_str("char.utf8") == '[b1_lead {b2_lead c_byte} {b3_lead c_byte{2,2}} {b4_lead c_byte{3,3}}]'
}

/* */
