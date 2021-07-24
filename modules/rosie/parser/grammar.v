module parser

fn (mut parser Parser) parse_grammar() ? {
	defer { parser.scope_idx = 0 }

	parser.scopes << Scope{}
	parser.scope_idx = parser.scopes.len - 1
	mut idx := parser.scope_idx

	for !parser.is_eof() {
		if parser.peek_text("end") {
			break
		} else if parser.peek_text("in") {
			idx = 0
		} else {
			parser.parse_binding(idx)?
		}
	}
}
