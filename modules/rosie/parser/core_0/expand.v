module core_0

import rosie.parser.common as core
import rosie.runtime_v2 as rt


// expand Determine the binding by name and expand it's pattern (replace macros)
pub fn (mut parser Parser) expand(varname string) ? core.Pattern {
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
fn (mut parser Parser) expand_pattern(orig core.Pattern) ? core.Pattern {
	mut pat := orig

	//eprintln("Expand pattern: ${orig.repr()}")

	match orig.elem {
		core.LiteralPattern { }
		core.CharsetPattern {
			count, ch := orig.elem.cs.count()
			if count == 1 {
				pat.elem = core.LiteralPattern{ text: ch.ascii_str() }
			}
		}
		core.GroupPattern {
			mut ar := []core.Pattern{ cap: orig.elem.ar.len }
			for p in orig.elem.ar {
				x := parser.expand_pattern(p)?
				ar << x
			}
			pat.elem = core.GroupPattern{ word_boundary: orig.elem.word_boundary, ar: ar }
		}
		core.DisjunctionPattern {
			mut ar := []core.Pattern{ cap: orig.elem.ar.len }
			for p in orig.elem.ar {
				x := parser.expand_pattern(p)?
				ar << x
			}
			pat.elem = core.DisjunctionPattern{ negative: orig.elem.negative, ar: ar }
		}
		core.NamePattern {
			//eprintln("orig.elem.text: $orig.elem.text, p.package: ${parser.package}, p.grammar: ${parser.grammar}")
			mut b := parser.binding(orig.elem.name)?
			//eprintln("binding: ${b.repr()}")
			if b.full_name() in parser.recursions {
				if parser.debug > 2 { eprintln("Detected recursion: '${b.full_name()}'") }
				b.func = true	// TODO doesn't seem to have an effect
				b.recursive = true
			} else {
				parser.expand(orig.elem.name)?
			}
		}
		core.EofPattern { }
		core.MacroPattern {
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
					pat.elem = core.MacroPattern{ name: orig.elem.name, pat: inner_pat }
				}
				else {
					pat.elem = core.MacroPattern{ name: orig.elem.name, pat: inner_pat }
				}
			}
		}
		core.FindPattern {
			inner_pat := parser.expand_pattern(orig.elem.pat)?
			pat.elem = core.FindPattern{ keepto: orig.elem.keepto, pat: inner_pat }
		}
	}

	return pat
}

fn (mut parser Parser) expand_find_macro(name string, orig core.Pattern) core.Pattern {
	// grammar
	//    alias <search> = {!"w" .}*
	//    <anonymous> = {"w"}
	// in
	//    alias find = {<search> <anonymous>}
	// end

	max := if name == "findall" { -1 } else { 1 }
	return core.Pattern{ min: 1, max: max, elem: core.FindPattern{ keepto: name == "keepto", pat: orig } }
}

fn (mut parser Parser) make_pattern_case_insensitive(orig core.Pattern) ? core.Pattern {
	mut pat := orig

	//eprintln("ci: ${orig.repr()}")

	match orig.elem {
		core.LiteralPattern {
			text := orig.elem.text
			mut ar := []core.Pattern{ cap: text.len * 2 }
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
					ar << core.Pattern{ elem: core.CharsetPattern{ cs: cs } }
				} else {
					ar << core.Pattern{ elem: core.LiteralPattern{ text: cl } }
				}
			}

			if ar.len == 1 {
				pat = ar[0]
			} else {
				pat = core.Pattern{ elem: core.GroupPattern{ word_boundary: false, ar: ar } }
			}
		}
		core.CharsetPattern {
			pat.elem = core.CharsetPattern{ cs: orig.elem.cs.to_case_insensitive() }
		}
		core.GroupPattern {
			mut ar := []core.Pattern{ cap: orig.elem.ar.len }
			for p in orig.elem.ar {
				x := parser.make_pattern_case_insensitive(p)?
				ar << x
			}
			pat.elem = core.GroupPattern{ word_boundary: orig.elem.word_boundary, ar: ar }
		}
		core.DisjunctionPattern {
			mut ar := []core.Pattern{ cap: orig.elem.ar.len }
			for p in orig.elem.ar {
				x := parser.make_pattern_case_insensitive(p)?
				ar << x
			}
			pat.elem = core.DisjunctionPattern { negative: orig.elem.negative, ar: ar }
		}
		core.NamePattern {
			// TODO validate this is working
			mut b := parser.binding(orig.elem.name)?
			b.pattern = parser.make_pattern_case_insensitive(b.pattern)?
		}
		core.EofPattern { }
		core.MacroPattern {
			x := parser.make_pattern_case_insensitive(orig.elem.pat)?
			pat.elem = core.MacroPattern{ name: orig.elem.name, pat: x }
		}
		core.FindPattern {
			x := parser.make_pattern_case_insensitive(orig.elem.pat)?
			pat.elem = core.FindPattern{ keepto: orig.elem.keepto, pat: x }
		}
	}

	return pat
}

fn (mut parser Parser) expand_tok_macro(orig core.Pattern) core.Pattern {
	if orig.elem is core.GroupPattern {
		// Transform (a b) to {a ~ b}
		mut ar := []core.Pattern{}
		if orig.elem.ar.len == 0 {
			panic("Should never happen")
		} else if orig.elem.ar.len == 1 {
			ar << orig.elem.ar[0]
		} else {
			ar << orig.elem.ar[0]

			for i := 1; i < orig.elem.ar.len; i++ {
				ar << core.Pattern{ elem: core.NamePattern{ name: "~" } }
				ar << orig.elem.ar[i]
			}
		}

		mut elem := core.GroupPattern{ word_boundary: false, ar: ar }

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
		mut g := core.Pattern{ elem: core.GroupPattern{ word_boundary: false, ar: [
			core.Pattern{ elem: core.NamePattern{ name: "~" } },
			core.Pattern{ elem: elem }
		] } }

		g.min = if orig.min == 0 { 0 } else { orig.min - 1 }
		g.max = if orig.max == -1 { -1 } else { orig.max - 1 }

		pat.elem = core.GroupPattern{ word_boundary: false, ar: [ core.Pattern{ elem: elem }, g ] }
		pat.min = if orig.min == 0 { 0 } else { 1 }
		pat.max = 1

		return pat
	}

	return orig
}

fn (mut parser Parser) expand_or_macro(orig core.Pattern) core.Pattern {
	if orig.elem is core.GroupPattern {
		if orig.elem.ar.len == 1 && orig.is_standard() {
			return orig.elem.ar[0]
		} else if orig.elem.ar.len == 1 && orig.elem.ar[0].is_standard() {
			mut pat := orig
			pat.elem = orig.elem.ar[0].elem
			return pat
		}
		mut pat := orig
		pat.elem = core.DisjunctionPattern{ negative: false, ar: orig.elem.ar }
		return pat
	}

	return orig
}