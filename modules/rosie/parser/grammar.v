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

	name := "${parser.package}.grammar-${parser.package_cache.packages.len}"
	parser.package = name
	parser.grammar = name
	parser.package_cache.add_package(fpath: name, name: name, parent: parent_pckg)?		// TODO Why does a package have a parent??

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
		for b in parser.package().bindings {
			if parent.has_binding(b.name) {
				fname := if parser.file.len == 0 { "<unknown>" } else { parser.file }
				return error("Pattern name already defined: '$b.name' in file '$fname'")
			}

			parent.bindings << b
		}

		mut ar := parser.package().bindings
		ar.clear()
	}
}
