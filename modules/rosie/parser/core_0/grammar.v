// ----------------------------------------------------------------------------
// Grammar specific parser utils
// ----------------------------------------------------------------------------

module core_0


fn (mut parser Parser) parse_grammar() ? {
	if parser.debug > 19 {
		eprintln(">> ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}")
		defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}") }
	}

	defer { parser.current = parser.main }

	parser.current = parser.main.package_cache.add_grammar(parser.current, "")?
	grammar := parser.current.name
	eprintln("Grammar: current='$parser.current.name'")

	mut has_in := false
	for !parser.is_eof() {
		if parser.last_token == .semicolon {
			parser.next_token()?
		} else if parser.peek_text("end") {
			break
		} else if parser.peek_text("in") {
			has_in = true
			parser.current = parser.main
		} else {
			parser.parse_binding(grammar: grammar)?
		}
	}

	if has_in == false {
		for b in parser.current.bindings {
			parser.main.add_binding(b)?
		}

		parser.current.bindings.clear()
	}
}
