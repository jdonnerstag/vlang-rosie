// ----------------------------------------------------------------------------
// Grammar specific parser utils
// ----------------------------------------------------------------------------

module stage_0


fn (mut p Parser) parse_grammar() ? {
	if p.debug > 19 {
		eprintln(">> ${@FN}: tok=$p.last_token, eof=${p.is_eof()}")
		defer { eprintln("<< ${@FN}: tok=$p.last_token, eof=${p.is_eof()}") }
	}

	defer { p.current = p.main }

	name := "grammar-${p.current.imports.len}"
	p.current = p.current.new_grammar(name)?

	mut grammar := ""
	mut has_in := false
	for !p.is_eof() {
		if p.last_token == .semicolon {
			p.next_token()?
		} else if p.peek_text("end") {
			break
		} else if p.peek_text("in") {
			has_in = true
			grammar = name
			p.current = p.main
		} else {
			p.parse_binding(grammar: grammar)?
		}
	}

	if has_in == false {
		for b in p.current.bindings {
			mut b2 := b
			b2.grammar = p.current.name
			p.main.new_binding(b2)?
		}

		p.current.bindings.clear()
	}
}
