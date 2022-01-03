module expander

import rosie

struct Expander {
	debug int
mut:
	current &rosie.Package
	recursions []string		// Detect recursions
}

[params]
pub struct FnNewExpanderOptions {
	main &rosie.Package
	debug int
}

pub fn new_expander(args FnNewExpanderOptions) Expander {
	return Expander{
		current: args.main
		debug: args.debug
	}
}

[inline]
pub fn (e Expander) binding(name string) ? &rosie.Binding {
	return e.current.get(name)
}

[inline]
pub fn (e Expander) get_package(name string) ? &rosie.Package {
	return e.current.package_cache.get(name)
}

fn (mut e Expander) update_current(b &rosie.Binding) ? {
	if b.grammar.len > 0 {
		e.current = e.get_package(b.grammar)?
	} else if b.package.len == 0 || b.package == "main" {
		// do nothing
	} else {
		e.current = e.get_package(b.package)?
	}
}

// expand Determine the binding by name and expand it's pattern (replace macros)
pub fn (mut e Expander) expand(name string) ? rosie.Pattern {
	mut b := e.binding(name)?
	if b.expanded {
		return b.pattern
	}
	b.expanded = true
	//if e.debug > 1 { eprintln("Expand INPUT: ${b.repr()}; package: $e.package, imports: ${e.package().imports}") }

	// TODO It seems we are expanding the same pattern many times, e.g. net.ipv4. Which is not the same as recursion
	// TODO Not sure we (still) need this
	e.recursions << b.full_name()
	defer { e.recursions.pop() }

	orig_current := e.current
	defer { e.current = orig_current }

	e.update_current(b)?

	b.pattern = e.expand_pattern(b.pattern)?
	//if e.debug > 1 { eprintln("Expand OUTPUT: ${b.repr()}") }

	return b.pattern
}

// expand_pattern Expand the pattern provided
fn (mut e Expander) expand_pattern(orig rosie.Pattern) ? rosie.Pattern {
	mut pat := orig

	//eprintln("Expand pattern='${orig.repr()}'; current='$e.current.name'")

	match orig.elem {
		rosie.LiteralPattern { }
		rosie.CharsetPattern {
			count, ch := orig.elem.cs.count()
			if count == 1 {
				pat.elem = rosie.LiteralPattern{ text: ch.ascii_str() }
			}
		}
		rosie.GroupPattern {
			mut ar := []rosie.Pattern{ cap: orig.elem.ar.len }
			for p in orig.elem.ar {
				x := e.expand_pattern(p)?
				ar << x
			}
			pat.elem = rosie.GroupPattern{ word_boundary: orig.elem.word_boundary, ar: ar }
		}
		rosie.DisjunctionPattern {
			mut ar := []rosie.Pattern{ cap: orig.elem.ar.len }
			for p in orig.elem.ar {
				x := e.expand_pattern(p)?
				ar << x
			}
			pat.elem = rosie.DisjunctionPattern{ negative: orig.elem.negative, ar: ar }
		}
		rosie.NamePattern {
			//eprintln("orig.elem.name='$orig.elem.name', p.main: ${e.main.name}, p.current: ${e.current.name}")
			mut b := e.binding(orig.elem.name) or {
				e.current.print_bindings()
				return err
			}
			//eprintln("expand: NamePattern: binding: ${b.repr()}")
			if b.full_name() in e.recursions {
				if e.debug > 2 { eprintln("Detected recursion: '${b.full_name()}'") }
				b.func = true	// TODO doesn't seem to have an effect
				b.recursive = true
			} else {
				e.expand(orig.elem.name)?
			}
		}
		rosie.EofPattern { }
		rosie.MacroPattern {
			//eprintln("orig.elem.name: $orig.elem.name")
			inner_pat := e.expand_pattern(orig.elem.pat)?

			// TODO this is rather hard-coded. Can we make this more flexible?
			match orig.elem.name {
				"tok" {
					pat = e.expand_tok_macro(inner_pat)
				}
				"or" {
					pat = e.expand_or_macro(inner_pat)
				}
				"ci" {
					pat = e.make_pattern_case_insensitive(inner_pat)?
				}
				"find", "keepto", "findall" {
					pat = e.expand_find_macro(orig.elem.name, inner_pat)
				}
				"backref" {
					pat.elem = rosie.MacroPattern{ name: orig.elem.name, pat: inner_pat }
				}
				else {
					pat.elem = rosie.MacroPattern{ name: orig.elem.name, pat: inner_pat }
				}
			}
		}
		rosie.FindPattern {
			inner_pat := e.expand_pattern(orig.elem.pat)?
			pat.elem = rosie.FindPattern{ keepto: orig.elem.keepto, pat: inner_pat }
		}
	}

	return pat
}

fn (mut e Expander) expand_find_macro(name string, orig rosie.Pattern) rosie.Pattern {
	// grammar
	//    alias <search> = {!"w" .}*
	//    <anonymous> = {"w"}
	// in
	//    alias find = {<search> <anonymous>}
	// end

	max := if name == "findall" { -1 } else { 1 }
	return rosie.Pattern{ min: 1, max: max, elem: rosie.FindPattern{ keepto: name == "keepto", pat: orig } }
}

fn (mut e Expander) make_pattern_case_insensitive(orig rosie.Pattern) ? rosie.Pattern {
	mut pat := orig

	//eprintln("ci: ${orig.repr()}")

	match orig.elem {
		rosie.LiteralPattern {
			text := orig.elem.text
			mut ar := []rosie.Pattern{ cap: text.len * 2 }
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
					mut cs := rosie.new_charset()
					cs.set_char(ltext[i])
					cs.set_char(utext[i])
					ar << rosie.Pattern{ elem: rosie.CharsetPattern{ cs: cs } }
				} else {
					ar << rosie.Pattern{ elem: rosie.LiteralPattern{ text: cl } }
				}
			}

			if ar.len == 1 {
				pat = ar[0]
			} else {
				pat = rosie.Pattern{ elem: rosie.GroupPattern{ word_boundary: false, ar: ar } }
			}
		}
		rosie.CharsetPattern {
			pat.elem = rosie.CharsetPattern{ cs: orig.elem.cs.to_case_insensitive() }
		}
		rosie.GroupPattern {
			mut ar := []rosie.Pattern{ cap: orig.elem.ar.len }
			for p in orig.elem.ar {
				x := e.make_pattern_case_insensitive(p)?
				ar << x
			}
			pat.elem = rosie.GroupPattern{ word_boundary: orig.elem.word_boundary, ar: ar }
		}
		rosie.DisjunctionPattern {
			mut ar := []rosie.Pattern{ cap: orig.elem.ar.len }
			for p in orig.elem.ar {
				x := e.make_pattern_case_insensitive(p)?
				ar << x
			}
			pat.elem = rosie.DisjunctionPattern { negative: orig.elem.negative, ar: ar }
		}
		rosie.NamePattern {
			// TODO validate this is working
			mut b := e.binding(orig.elem.name)?
			b.pattern = e.make_pattern_case_insensitive(b.pattern)?
		}
		rosie.EofPattern { }
		rosie.MacroPattern {
			x := e.make_pattern_case_insensitive(orig.elem.pat)?
			pat.elem = rosie.MacroPattern{ name: orig.elem.name, pat: x }
		}
		rosie.FindPattern {
			x := e.make_pattern_case_insensitive(orig.elem.pat)?
			pat.elem = rosie.FindPattern{ keepto: orig.elem.keepto, pat: x }
		}
	}

	return pat
}

fn (mut e Expander) expand_tok_macro(orig rosie.Pattern) rosie.Pattern {
	if orig.elem is rosie.GroupPattern {
		// Transform (a b) to {a ~ b}
		mut ar := []rosie.Pattern{}
		if orig.elem.ar.len == 0 {
			panic("Should never happen")
		} else if orig.elem.ar.len == 1 {
			ar << orig.elem.ar[0]
		} else {
			ar << orig.elem.ar[0]

			for i := 1; i < orig.elem.ar.len; i++ {
				ar << rosie.Pattern{ elem: rosie.NamePattern{ name: "~" } }
				ar << orig.elem.ar[i]
			}
		}

		mut elem := rosie.GroupPattern{ word_boundary: false, ar: ar }

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
		mut g := rosie.Pattern{ elem: rosie.GroupPattern{ word_boundary: false, ar: [
			rosie.Pattern{ elem: rosie.NamePattern{ name: "~" } },
			rosie.Pattern{ elem: elem }
		] } }

		g.min = if orig.min == 0 { 0 } else { orig.min - 1 }
		g.max = if orig.max == -1 { -1 } else { orig.max - 1 }

		pat.elem = rosie.GroupPattern{ word_boundary: false, ar: [ rosie.Pattern{ elem: elem }, g ] }
		pat.min = if orig.min == 0 { 0 } else { 1 }
		pat.max = 1

		return pat
	}

	return orig
}

fn (mut e Expander) expand_or_macro(orig rosie.Pattern) rosie.Pattern {
	if orig.elem is rosie.GroupPattern {
		if orig.elem.ar.len == 1 && orig.is_standard() {
			return orig.elem.ar[0]
		} else if orig.elem.ar.len == 1 && orig.elem.ar[0].is_standard() {
			mut pat := orig
			pat.elem = orig.elem.ar[0].elem
			return pat
		}
		mut pat := orig
		pat.elem = rosie.DisjunctionPattern{ negative: false, ar: orig.elem.ar }
		return pat
	}

	return orig
}