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

fn test_import() ? {
	mut p := parse_and_expand('
grammar
	yyy = "a"
in
	xxx = yyy
end
', "xxx", 0)?

	//p.main.print_bindings()
	assert p.main.get("xxx")?.package == "main"
	assert p.main.get("xxx")?.grammar == "grammar-0"
	assert p.main.get("grammar-0.yyy")?.package == "grammar-0"
	assert p.main.get("grammar-0.yyy")?.grammar == ""
}
/* */