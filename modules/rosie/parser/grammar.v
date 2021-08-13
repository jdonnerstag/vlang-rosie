// ----------------------------------------------------------------------------
// Grammar specific parser utils
// ----------------------------------------------------------------------------

module parser

fn (mut parser Parser) parse_grammar() ? {
	parent_pckg := parser.package
	parser.package = "grammar-${parser.package_cache.packages.len}"
	parser.package_cache.add_package(fpath: parser.package, name: parser.package)?

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
