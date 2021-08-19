// ----------------------------------------------------------------------------
// Grammar specific parser utils
// ----------------------------------------------------------------------------

module parser

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

	name := "grammar-${parser.package_cache.packages.len}"
	parser.package = name
	parser.grammar = name
	parser.package_cache.add_package(fpath: name, name: name, parent: parent_pckg)?

	for !parser.is_eof() {
		if parser.last_token == .semicolon {
			parser.next_token()?
		} else if parser.peek_text("end") {
			break
		} else if parser.peek_text("in") {
			parser.package = parent_pckg
		} else {
			parser.parse_binding()?
		}
	}
}
