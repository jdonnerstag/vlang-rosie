// ----------------------------------------------------------------------------
// import statement related parser utils
// ----------------------------------------------------------------------------

module parser

import os


fn (mut parser Parser) read_header() ? {
	if parser.debug > 98 {
		eprintln(">> ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}")
		defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}") }
	}

	parser.next_token()?

	if parser.peek_text("rpl") {
		parser.package.language = parser.get_text()
	}

	if parser.peek_text("package") {
		parser.package.name = parser.get_text()
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
		if str in parser.package.imports {
			return error("Warning: import packages only once: '$str'")
		}

		parser.next_token() or {
			parser.package.imports[str] = parser.find_rpl_file(str)?
			return err
		}

		mut alias := ""
		if parser.peek_text("as") {
			alias = t.get_text()
			parser.package.imports[alias] = parser.find_rpl_file(str)?
			parser.next_token() or { break }
		} else {
			alias = str
			parser.package.imports[alias] = parser.find_rpl_file(str)?
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

fn (mut parser Parser) find_rpl_file(name string) ? string {
	if name.len == 0 {
		return error("Import name must not be empty. File=$parser.file")
	}

	for p in parser.import_path {
		f := "${p}/${name}.rpl"
		if os.is_file(f) {
			return os.real_path(f)
		}
	}

	return error("File for import package not found: name=$name, $parser.import_path")
}

// TODO
fn (mut parser Parser) import_package(name string, alias string) ? {
	if name.len == 0 {
		return error("Package name must not be empty")
	}
/*
	// TODO: Skip if package (file) has been imported already
	for _, e in parser.package.imports {
		if e.fname == fname {
			return
		}
	}

	data := os.read_file(fname) or {
		return error("Failed to import rpl file for '$fname'")
	}

	mut p := new_parser(data: data, debug: 0)?
	p.parse() or {
		return error("Parser Error: ${err.msg}; rpl-file=$fname")
	}

	// TODO: Import the public bindings
*/
}
