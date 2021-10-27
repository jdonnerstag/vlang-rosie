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
		parser.package().language = parser.get_text()
	}

	if parser.peek_text("package") {
		name := parser.get_text()
		parser.package().name = name
		parser.package = name
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
		if str in parser.package().imports {
			return error("Warning: import packages only once: '$str'")
		}

		parser.next_token() or {
			parser.import_package(str, str)?
			return err
		}

		mut alias := ""
		if parser.peek_text("as") {
			alias = t.get_text()
			parser.import_package(alias, str)?
			parser.next_token() or { break }
		} else {
			parser.import_package(str, str)?
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
	if name.ends_with(".rpl") {
		return parser.find_rpl_file(name[0 .. name.len - 4])
	}

	if name.len == 0 {
		return error("Import name must not be empty. File=$parser.file")
	}

	for p in parser.import_path {
		if f := parser.find_rpl_file_("${p}/${name}") {
			return f
		}
	}

	if f := parser.find_rpl_file_(name) {
		return f
	}

	return error("Import package: File not found: name='$name', path=${parser.import_path}. ")
}

fn (mut parser Parser) find_rpl_file_(name string) ? string {
	if os.is_file(name) {
		return os.real_path(name)
	}

	fp := "${name}.rpl"
	if os.is_file(fp) {
		return os.real_path(fp)
	}

	return none
}

fn (mut parser Parser) find_and_load_package(name string) ?string {
	fpath := parser.find_rpl_file(name)?

	if parser.package_cache.contains(fpath) {
		return fpath
	}

	if parser.debug > 10 {
		eprintln(">> Import: load and parse '$fpath'")
		defer { eprintln("<< Import: load and parse '$fpath'") }
	}

	xname := name.all_after_last("/").all_after_last("\\")
	mut p := new_parser(package: xname, fpath: fpath, debug: parser.debug, package_cache: parser.package_cache) or {
		return error("${err.msg}; file: $fpath")
	}
	p.parse() or {
		return error("${err.msg}; file: $fpath")
	}

	return fpath
}

fn (mut parser Parser) import_package(alias string, name string) ? {
	fpath := parser.find_and_load_package(name)?
	//eprintln("Import package: alias: $alias, name: $name, fpath: $fpath")
	parser.package().imports[alias] = fpath
}
