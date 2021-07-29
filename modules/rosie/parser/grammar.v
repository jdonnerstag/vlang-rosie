// ----------------------------------------------------------------------------
// Grammar specific parser utils
// ----------------------------------------------------------------------------

module parser

fn (mut parser Parser) parse_grammar() ? {
	parent_pckg := parser.package_name
	defer { parser.package_name = parent_pckg }

	parser.package_name = "grammar-${parser.packages.len}"
	parser.packages[parser.package_name] = Scope{}
	mut scope := parser.package_name

	for !parser.is_eof() {
		if parser.last_token == .semicolon {
			parser.next_token()?
		} else if parser.peek_text("end") {
			break
		} else if parser.peek_text("in") {
			scope = parent_pckg
		} else {
			parser.parse_binding(scope)?
		}
	}
}
