module parser

import rosie.runtime_v2 as rt


// expand Determine the binding by name and expand it's pattern (replace macros)
pub fn (mut parser Parser) expand(varname string) ? Pattern {
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
		DisjunctionPattern {
			mut ar := []Pattern{ cap: orig.elem.ar.len }
			for p in orig.elem.ar {
				x := parser.expand_pattern(p)?
				ar << x
			}
			pat.elem = DisjunctionPattern{ negative: orig.elem.negative, ar: ar }
		}
		NamePattern {
			//eprintln("orig.elem.text: $orig.elem.text, p.package: ${parser.package}, p.grammar: ${parser.grammar}")
			mut b := parser.binding(orig.elem.name)?
			eprintln("binding: ${b.repr()}")
			if b.full_name() in parser.recursions {
				if parser.debug > 2 { eprintln("Detected recursion: '${b.full_name()}'") }
				b.func = true	// TODO doesn't seem to have an effect
				b.recursive = true
			} else {
				parser.expand(orig.elem.name)?
			}
		}
		EofPattern { }
		MacroPattern {
			//eprintln("orig.elem.name: $orig.elem.name")
			inner_pat := parser.expand_pattern(orig.elem.pat)?

			// TODO this is rather hard-coded. Can we make this more flexible?
			match orig.elem.name {
				"tok" {
					pat = parser.expand_tok_macro(inner_pat)
				}
				"or" {
					pat = parser.expand_or_macro(inner_pat)
				}
				"ci" {
					pat = parser.make_pattern_case_insensitive(inner_pat)?
				}
				"find", "keepto", "findall" {
					pat = parser.expand_find_macro(orig.elem.name, inner_pat)
				}
				"backref" {
					pat.elem = MacroPattern{ name: orig.elem.name, pat: inner_pat }
				}
				else {
					pat.elem = MacroPattern{ name: orig.elem.name, pat: inner_pat }
				}
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

	max := if name == "findall" { -1 } else { 1 }
	return Pattern{ min: 1, max: max, elem: FindPattern{ keepto: name == "keepto", pat: orig } }
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
					/*
					a := Pattern{ elem: LiteralPattern{ text: cl } }
					b := Pattern{ elem: LiteralPattern{ text: cu } }
					ar << Pattern{ elem: DisjunctionPattern{ negative: false, ar: [a, b] } }
					*/
					mut cs := rt.new_charset()
					cs.set_char(ltext[i])
					cs.set_char(utext[i])
					ar << Pattern{ elem: CharsetPattern{ cs: cs } }
				} else {
					ar << Pattern{ elem: LiteralPattern{ text: cl } }
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
		DisjunctionPattern {
			mut ar := []Pattern{ cap: orig.elem.ar.len }
			for p in orig.elem.ar {
				x := parser.make_pattern_case_insensitive(p)?
				ar << x
			}
			pat.elem = DisjunctionPattern { negative: orig.elem.negative, ar: ar }
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

fn (mut parser Parser) expand_tok_macro(orig Pattern) Pattern {
	if orig.elem is GroupPattern {
		// Transform (a b) to {a ~ b}
		mut ar := []Pattern{}
		if orig.elem.ar.len == 0 {
			panic("Should never happen")
		} else if orig.elem.ar.len == 1 {
			ar << orig.elem.ar[0]
		} else {
			ar << orig.elem.ar[0]

			for i := 1; i < orig.elem.ar.len; i++ {
				ar << Pattern{ elem: NamePattern{ name: "~" } }
				ar << orig.elem.ar[i]
			}
		}

		mut elem := GroupPattern{ word_boundary: false, ar: ar }

		// (a) => {a}
		// (a)? => {a}?
		// (a)+ => {a {~ a}*}
		// (a)* => {a {~ a}*}?
		// (a){2} => {a {~ a}{1,1}}
		// (a){0,4} => {a {~ a}{0,3}}?
		// (a){1,4} => {a {~ a}{0,3}}
		// (a){2,4} => {a {~ a}{1,3}}
		mut pat := orig
		if orig.max == 1 {
			pat.elem = elem
			return pat
		}

		// The {~ a} group
		mut g := Pattern{ elem: GroupPattern{ word_boundary: false, ar: [
			Pattern{ elem: NamePattern{ name: "~" } },
			Pattern{ elem: elem }
		] } }

		g.min = if orig.min == 0 { 0 } else { orig.min - 1 }
		g.max = if orig.max == -1 { -1 } else { orig.max - 1 }

		pat.elem = GroupPattern{ word_boundary: false, ar: [ Pattern{ elem: elem }, g ] }
		pat.min = if orig.min == 0 { 0 } else { 1 }
		pat.max = 1

		return pat
	}

	return orig
}

fn (mut parser Parser) expand_or_macro(orig Pattern) Pattern {
	if orig.elem is GroupPattern {
		if orig.elem.ar.len == 1 && orig.is_standard() {
			return orig.elem.ar[0]
		} else if orig.elem.ar.len == 1 && orig.elem.ar[0].is_standard() {
			mut pat := orig
			pat.elem = orig.elem.ar[0].elem
			return pat
		}
		mut pat := orig
		pat.elem = DisjunctionPattern{ negative: false, ar: orig.elem.ar }
		return pat
	}

	return orig
}