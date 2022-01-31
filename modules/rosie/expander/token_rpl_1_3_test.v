
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

fn test_tok() ? {
	mut p := parse_and_expand('tok:{"a"}', "*", 0)?
	assert p.pattern_str("*") == '{~ {"a" ~}}'

	p = parse_and_expand('tok:{"a"}?', "*", 0)?
	assert p.pattern_str("*") == '{~ {"a" ~}}?'

	p = parse_and_expand('tok:{"a"}+', "*", 0)?
	assert p.pattern_str("*") == '{~ {"a" ~}+}'

	p = parse_and_expand('tok:{"a"}*', "*", 0)?
	assert p.pattern_str("*") == '{~ {"a" ~}*}?'

	p = parse_and_expand('tok:{"a"}{2,2}', "*", 0)?
	assert p.pattern_str("*") == '{~ {"a" ~}{2,2}}'

	p = parse_and_expand('tok:{"a" "b"}', "*", 0)?
	assert p.pattern_str("*") == '{~ {"a" ~ "b" ~}}'

	p = parse_and_expand('tok:["a" "b"]', "*", 0)?
	assert p.pattern_str("*") == '{~ {{"a" / "b"} ~}}}'
}

fn test_tok_parentheses() ? {
	mut p := parse_and_expand('("a" "b")', "*", 0)?
	assert p.pattern_str("*") == '{~ {"a" ~}}'

	p = parse_and_expand('("a")?', "*", 0)?
	assert p.pattern_str("*") == '{~ {"a" ~}}?'

	p = parse_and_expand('("a")+', "*", 0)?
	assert p.pattern_str("*") == '{~ {"a" ~}+}'

	p = parse_and_expand('("a")*', "*", 0)?
	assert p.pattern_str("*") == '{~ {"a" ~}*}?'

	p = parse_and_expand('("a"){2,2}', "*", 0)?
	assert p.pattern_str("*") == '{~ {"a" ~}{2,2}}'

	p = parse_and_expand('("a" "b")', "*", 0)?
	assert p.pattern_str("*") == '{~ {"a" ~ "b" ~}}'

	p = parse_and_expand('(["a" "b"])', "*", 0)?
	assert p.pattern_str("*") == '{~ {{"a" / "b"} ~}}}'
}
/* */
