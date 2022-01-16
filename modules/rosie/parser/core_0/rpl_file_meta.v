// ----------------------------------------------------------------------------
// import statement related parser utils
// ----------------------------------------------------------------------------

module core_0

import os
import rosie

fn (mut parser Parser) read_header() ? {
	if parser.debug > 98 {
		eprintln(">> ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}")
		defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}") }
	}

	// The 'rpl' statement must be first, but is optional
	parser.next_token()?
	if parser.peek_text("rpl") {
		language := parser.get_text()
		parser.main.language = language
		if language.starts_with("1.") == false {
			return error_with_code(
				"RPL error: the selected parser does not support RPL ${language}",
				rosie.err_rpl_version_not_supported
			)
		}
	}

	// The 'package' statement may follow, but is optional as well
	if parser.peek_text("package") {
		name := parser.get_text()
		parser.main.name = name
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
			parser.add_import_placeholder(str, str)?
			return err
		}

		mut alias := ""
		if parser.peek_text("as") {
			alias = t.get_text()
			parser.add_import_placeholder(alias, str)?
			parser.next_token() or { break }
		} else {
			parser.add_import_placeholder(str, str)?
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

fn (mut parser Parser) find_and_load_package(fpath string) ? &rosie.Package {
	if pkg := parser.package_cache.get(fpath) {
		return pkg
	}

	if parser.debug > 10 {
		eprintln(">> Import: load and parse '$fpath' into '$parser.main.name'")
		defer { eprintln("<< Import: load and parse '$fpath'") }
	}

	mut p := new_parser(debug: parser.debug, package_cache: parser.package_cache ) or {
		return error("${err.msg}; file: $fpath")
	}

	p.parse(file: fpath) or {
		return error("${err.msg}; file: $fpath")
	}

	return p.main
}

fn (mut p Parser) import_packages() ? {
	for stmt in p.imports {
		pkg := p.find_and_load_package(stmt.fpath)?
		p.main.imports[stmt.alias] = pkg

		if p.package_cache.contains(pkg.name) == false {
			p.package_cache.add_package(pkg)?
		}
	}
}

fn (mut p Parser) add_import_placeholder(alias string, name string) ? {
	fpath := p.find_rpl_file(name)?
	if p.imports.any(it.fpath == fpath) {
		return error("Import packages only ones: '$alias', fpath='$fpath'")
	}

	p.imports << rosie.ImportStmt{ alias: alias, fpath: fpath }
}
