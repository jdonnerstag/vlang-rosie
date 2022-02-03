
import rosie
import rosie.expander
import rosie.parser.core_0 as parser

fn parse_and_expand(rpl string, name string, debug int) ? parser.Parser {
	mut p := parser.new_parser(debug: debug)?
	p.parse(data: rpl)?

	mut e := expander.new_expander(main: p.main, debug: p.debug, unit_test: false)
	e.expand(name)?

	return p
}

fn test_simple_binding() ? {
	mut p := parse_and_expand('alias ascii = "test" ', "ascii", 0)?
	//p.main.print_bindings()
	assert p.main.get_internal("ascii")?.public == true
	assert p.pattern("ascii")?.min == 1
	assert p.pattern("ascii")?.max == 1
	assert p.pattern("ascii")?.predicate == rosie.PredicateType.na
	//p.main.print_bindings()
	assert p.pattern("ascii")?.text()? == "test"

	p = parse_and_expand('local alias ascii = "test"', "ascii", 0)?
	assert p.main.get_internal("ascii")?.public == false
	assert p.pattern("ascii")?.min == 1
	assert p.pattern("ascii")?.max == 1
	assert p.pattern("ascii")?.predicate == rosie.PredicateType.na
	assert p.pattern("ascii")?.text()? == "test"

	p = parse_and_expand('ascii = "test"', "ascii", 0)?
	assert p.main.get_internal("ascii")?.public == true
	assert p.main.get_internal("ascii")?.alias == false
	assert p.pattern("ascii")?.text()? == "test"

	p = parse_and_expand('"test"', "*", 0)?
	assert p.main.get_internal("*")?.public == true
	assert p.pattern("*")?.min == 1
	assert p.pattern("*")?.max == 1
	assert p.pattern("*")?.predicate == rosie.PredicateType.na
	assert p.pattern("*")?.text()? == "test"
}

fn test_tilde() ? {
	mut p := parse_and_expand('alias ~ = [:space:]+; x = {"a" ~ {"b" ~}? "c"}', "x", 0)?
	//eprintln(p.binding("x")?)
	assert p.pattern("x")?.repr() == '{"a" ~ {"b" ~}? "c"}'
}

fn test_disjunction() ? {
	// -- If you are used to regex, the tagname expression below will look quite strange.  But
	// -- in RPL, a bracket expression is a disjunction of its contents, and inside a bracket
	// -- expression you can use literals like "/>" and even reference other patterns.
	mut p := parse_and_expand('tagname = [^ [:space:] [>] "/>"]+', "tagname", 0)?
	//eprintln(p.binding("x")?)
	assert p.pattern("tagname")?.repr() == '[^ [(9-13)(32)(62)] "/>"]+'
}

fn test_builtin_override() ? {
	mut p := parse_and_expand(r'builtin alias ~ = [ ]+; x = {"a" ~ "b"}', "~", 0)?
	assert p.package_cache.builtin().name == p.package_cache.builtin().name
	assert p.package_cache.builtin().has_binding("~")
	assert p.current.has_parent() == true
	assert p.current.parent.name == rosie.builtin
	assert p.pattern("~")?.repr() == '" "+'
	assert p.package_cache.builtin().get_internal("~")?.pattern.repr() == '" "+'
}
/* */