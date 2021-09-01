module parser


fn (mut parser Parser) expand(varname string) ? Pattern {
	b := parser.binding(varname)?
	//eprintln("Expand $b.name: ${b.repr()}")

	_, pat := parser.expand_pattern(b.pattern)?

	return pat
}

fn (mut parser Parser) expand_pattern(orig Pattern) ? (int, Pattern) {
	mut pat := orig
	mut count := 0

	//eprintln("Expand pattern: ${orig.repr()}")

	match orig.elem {
		LiteralPattern { }
		CharsetPattern { }
		GroupPattern {
			mut ar := []Pattern{ cap: orig.elem.ar.len }
			for p in orig.elem.ar {
				c, x := parser.expand_pattern(p)?
				count += c
				ar << x
			}
			pat.elem = GroupPattern{ word_boundary: orig.elem.word_boundary, ar: ar }
		}
		NamePattern {
			mut b := parser.binding(orig.elem.text)?
			if b.alias == true {
				c, x := parser.expand_pattern(b.pattern)?
				count += c
				pat = x
			}
		}
		EofPattern { }
		MacroPattern {
			//eprintln("orig.elem.name: $orig.elem.name")
			c, inner_pat := parser.expand_pattern(orig.elem.pat)?
			count += c

			if orig.elem.name == "ci" {
				c2, x := parser.make_pattern_case_insensitive(inner_pat)?
				count += c2
				pat = x
			} else if orig.elem.name in ["find", "keepto"] {
				pat = parser.expand_find_macro(orig.elem.name, inner_pat)
				count += 1
			} else {
				pat.elem = MacroPattern{ name: orig.elem.name, pat: inner_pat }
			}
		}
		FindPattern { }
	}

	return count, pat
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

fn (mut parser Parser) make_pattern_case_insensitive(orig Pattern) ? (int, Pattern) {
	mut count := 0
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
					a := Pattern{ operator: .choice, elem: LiteralPattern{ text: cl } }
					b := Pattern{ elem: LiteralPattern{ text: cu } }
					ar << Pattern{ elem: GroupPattern{ word_boundary: false, ar: [a, b] } }
				} else {
					ar << Pattern{ elem: LiteralPattern{ text: cl } }
				}
			}
			if ar.len == 1 {
				pat = ar[0]
			} else {
				pat = Pattern{ elem: GroupPattern{ word_boundary: false, ar: ar } }
			}
			count += 1
		}
		CharsetPattern {
			pat.elem = CharsetPattern{ cs: orig.elem.cs.to_case_insensitive() }
			count += 1
		}
		GroupPattern {
			mut ar := []Pattern{ cap: orig.elem.ar.len }
			for p in orig.elem.ar {
				c, x := parser.make_pattern_case_insensitive(p)?
				count += c
				ar << x
			}
			pat.elem = GroupPattern{ word_boundary: orig.elem.word_boundary, ar: ar }
		}
		NamePattern {
			// TODO validate this is working
			mut b := parser.binding(orig.elem.text)?
			c, x := parser.make_pattern_case_insensitive(b.pattern)?
			count += c
			b.pattern = x
		}
		EofPattern { }
		MacroPattern {
			c, x := parser.make_pattern_case_insensitive(orig.elem.pat)?
			count += c
			pat.elem = MacroPattern{ name: orig.elem.name, pat: x }

		}
		FindPattern {
			c, x := parser.make_pattern_case_insensitive(orig.elem.pat)?
			count += c
			pat.elem = FindPattern{ keepto: orig.elem.keepto, pat: x }
		}
	}

	return count, pat
}