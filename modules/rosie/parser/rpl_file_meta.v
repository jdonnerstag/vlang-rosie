// ----------------------------------------------------------------------------
// import statement related parser utils
// ----------------------------------------------------------------------------

module parser

struct Import {
pub:
	name string		// Package path
}

fn (mut parser Parser) read_header() ? {
	if parser.debug > 98 {
		eprintln(">> ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}")
		defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}") }
	}

	parser.next_token()?

	if parser.peek_text("rpl") {
		parser.language = parser.get_text()
	}

	if parser.peek_text("package") {
		parser.package = parser.get_text()
	}

	for parser.peek_text("import") {
		parser.read_import_stmt()?
	}
}

fn (mut parser Parser) read_import_stmt() ? {
	if parser.debug > 98 {
		eprintln(">> ${@FN} '${parser.tokenizer.scanner.text}': tok=$parser.last_token, eof=${parser.is_eof()}")
		defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}") }
	}

	mut t := &parser.tokenizer

	for true {
		str := parser.parse_import_path()?
		if str in parser.import_stmts {
			return error("Warning: import packages only once: '$str'")
		}

		parser.next_token() or {
			parser.import_stmts[str] = Import{ name: str }
			return err
		}

		if parser.peek_text("as") {
			alias := t.get_text()
			parser.import_stmts[alias] = Import{ name: str }
			parser.next_token() or { break }
		} else {
			parser.import_stmts[str] = Import{ name: str }
		}

		if parser.last_token != .comma { break }

		parser.next_token()?
	}
}

fn (mut parser Parser) parse_import_path() ?string {
	mut t := &parser.tokenizer
	if parser.last_token()? == .quoted_text {
		return t.get_quoted_text()
	}

	mut s := &t.scanner
	s.move_to_end_of_word()
	if s.pos > 0 && s.text[s.pos - 1] == `,` {
		s.pos --
	}

	return t.get_text()
}