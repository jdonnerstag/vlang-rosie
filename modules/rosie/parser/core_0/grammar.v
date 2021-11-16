// ----------------------------------------------------------------------------
// Grammar specific parser utils
// ----------------------------------------------------------------------------

module core_0


fn (mut parser Parser) parse_grammar() ? {
	if parser.debug > 19 {
		eprintln(">> ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}")
		defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}") }
	}

	parent_pckg := parser.package
	parent_grammar := parser.grammar
	defer {
		parser.package = parent_pckg
		parser.grammar = parent_grammar
	}

	name := parser.package_cache.add_grammar(parser.package)?.name
	//eprintln("grammr: $name")
	parser.package = name
	parser.grammar = name

	mut has_in := false
	for !parser.is_eof() {
		if parser.last_token == .semicolon {
			parser.next_token()?
		} else if parser.peek_text("end") {
			break
		} else if parser.peek_text("in") {
			has_in = true
			parser.package = parent_pckg
		} else {
			parser.parse_binding()?
		}
	}

	if has_in == false {
		mut parent := parser.package_cache.get(parent_pckg)?
		mut pkg := parser.package()
		for b in pkg.bindings {
			parent.add_binding(b)?
		}

		pkg.bindings.clear()
	}
}
