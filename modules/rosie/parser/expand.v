module parser


// expand Determine the binding by name and expand it's pattern
fn (mut parser Parser) expand(varname string) ? Pattern {
	mut b := parser.binding(varname)?
	//if parser.debug > 1 { eprintln("Expand INPUT: ${b.repr()}; package: $parser.package, imports: ${parser.package().imports}") }

	// TODO It seems we are expanding the same pattern many times, e.g. net.ipv4. Which is not the same as recursion
	parser.recursions << b.full_name()
	defer { parser.recursions.pop() }

	orig_package := parser.package
	parser.package = b.package
	defer { parser.package = orig_package }

	orig_grammar := parser.grammar
	parser.grammar = b.grammar
	defer { parser.grammar = orig_grammar }

	b.pattern = parser.expand_pattern(b.pattern)?
	//if parser.debug > 1 { eprintln("Expand OUTPUT: ${b.repr()}") }

	return b.pattern
}

// expand_pattern Expand the pattern provided
fn (mut parser Parser) expand_pattern(orig Pattern) ? Pattern {
	mut pat := orig

	//eprintln("Expand pattern: ${orig.repr()}")

	match orig.elem {
		LiteralPattern { }
		CharsetPattern { }
		GroupPattern {
			mut ar := []Pattern{ cap: orig.elem.ar.len }
			for p in orig.elem.ar {
				x := parser.expand_pattern(p)?
				ar << x
			}
			pat.elem = GroupPattern{ word_boundary: orig.elem.word_boundary, ar: ar }
		}
		NamePattern {
			//eprintln("orig.elem.text: $orig.elem.text, p.package: ${parser.package}, p.grammar: ${parser.grammar}")
			mut b := parser.binding(orig.elem.name)?
			//eprintln("binding: ${b.repr()}")
			if b.full_name() in parser.recursions {
				if parser.debug > 2 { eprintln("Detected recursion: '${b.full_name()}'") }
				b.func = true	// TODO doesn#t seem to have an effect
				b.recursive = true
			} else {
				parser.expand(orig.elem.name)?
			}
		}
		EofPattern { }
		MacroPattern {
			//eprintln("orig.elem.name: $orig.elem.name")
			inner_pat := parser.expand_pattern(orig.elem.pat)?

			if orig.elem.name == "ci" {
				pat = parser.make_pattern_case_insensitive(inner_pat)?
			} else if orig.elem.name in ["find", "keepto"] {
				pat = parser.expand_find_macro(orig.elem.name, inner_pat)
			} else {
				pat.elem = MacroPattern{ name: orig.elem.name, pat: inner_pat }
			}
		}
		FindPattern {
			inner_pat := parser.expand_pattern(orig.elem.pat)?
			pat.elem = FindPattern{ keepto: orig.elem.keepto, pat: inner_pat }
		}
	}

	return pat
}

fn (mut parser Parser) expand_find_macro(name string, orig Pattern) Pattern {
	// grammar
    //    alias <search> = {!"w" .}*
    //    <anonymous> = {"w"}
	// in
    //    alias find = {<search> <anonymous>}
	// end

	return Pattern{ word_boundary: false, elem: FindPattern{ keepto: name == "keepto", pat: orig } }
}

fn (mut parser Parser) make_pattern_case_insensitive(orig Pattern) ? Pattern {
	mut pat := orig

	//eprintln("ci: ${orig.repr()}")

	match orig.elem {
		LiteralPattern {
			text := orig.elem.text
			mut ar := []Pattern{ cap: text.len * 2 }
			ltext := text.to_lower()
			utext := text.to_upper()
			for i in 0 .. text.len {
				cl := ltext[i .. i + 1]
				cu := utext[i .. i + 1]
				if cl != cu {
					a := Pattern{ word_boundary: false, operator: .choice, elem: LiteralPattern{ text: cl } }
					b := Pattern{ word_boundary: false, elem: LiteralPattern{ text: cu } }
					ar << Pattern{ word_boundary: false, elem: GroupPattern{ word_boundary: false, ar: [a, b] } }
				} else {
					ar << Pattern{ word_boundary: false, elem: LiteralPattern{ text: cl } }
				}
			}
			if ar.len == 1 {
				pat = ar[0]
			} else {
				pat = Pattern{ elem: GroupPattern{ word_boundary: false, ar: ar } }
			}
		}
		CharsetPattern {
			pat.elem = CharsetPattern{ cs: orig.elem.cs.to_case_insensitive() }
		}
		GroupPattern {
			mut ar := []Pattern{ cap: orig.elem.ar.len }
			for p in orig.elem.ar {
				x := parser.make_pattern_case_insensitive(p)?
				ar << x
			}
			pat.elem = GroupPattern{ word_boundary: orig.elem.word_boundary, ar: ar }
		}
		NamePattern {
			// TODO validate this is working
			mut b := parser.binding(orig.elem.name)?
			b.pattern = parser.make_pattern_case_insensitive(b.pattern)?
		}
		EofPattern { }
		MacroPattern {
			x := parser.make_pattern_case_insensitive(orig.elem.pat)?
			pat.elem = MacroPattern{ name: orig.elem.name, pat: x }
		}
		FindPattern {
			x := parser.make_pattern_case_insensitive(orig.elem.pat)?
			pat.elem = FindPattern{ keepto: orig.elem.keepto, pat: x }
		}
	}

	return pat
}