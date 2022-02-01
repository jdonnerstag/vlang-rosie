module expander

// Expander Expanders are responsible to prepare the AST for compilation (byte-code
// generation). Which means
//  - replacing macros
//  - replacing (a b) with {a ~ b}
//  - add groups, e.g. {a b / c} => {a {b / c}}. The compiler itself has no idea of left- or right associativity, or preference
//  - few optimizations such [[:digit:][a-e]] to [01-9a-e] and others
// lead to more concise and faster and byte-code.
// Note: It very explicitly does not include replacing aliases with their code. Compiler's
// can do this very easily and it would only (significantly) grow the AST including
// all the memory allocations.

import rosie

struct Expander {
	debug int
	unit_test bool
mut:
	current &rosie.Package
	recursions []string		// Detect recursions
}

[params]
pub struct FnNewExpanderOptions {
	main &rosie.Package
	unit_test bool
	debug int
}

pub fn new_expander(args FnNewExpanderOptions) Expander {
	return Expander{
		current: args.main
		unit_test: args.unit_test
		debug: args.debug
	}
}

// expand Determine the binding by name and expand it's pattern (replace macros)
pub fn (mut e Expander) expand(name string) ? rosie.Pattern {
	mut b, new_current := e.current.get_bp(name)?
	if b.expanded {
		return b.pattern
	}
	b.expanded = true
	if e.debug > 10 {
		eprintln("Expand INPUT: name=$name; ${b.repr()}; package: $e.current.name, imports: ${e.current.imports.keys()}")
	}

	// TODO It seems we are expanding the same pattern many times, e.g. net.ipv4. Which is not the same as recursion
	// TODO Not sure we (still) need this
	e.recursions << b.full_name()
	defer { e.recursions.pop() }

	orig_current := e.current
	defer { e.current = orig_current }

	e.current = new_current

	b.pattern = e.expand_pattern(b.pattern)?
	b.pattern = e.eliminate_layer(b.pattern)

	if e.debug > 10 {
		eprintln("Expand OUTPUT: ${b.repr()}")
	}

	return b.pattern
}

fn (mut e Expander) suitable_for_expansion(orig &rosie.Pattern, p &rosie.Pattern) bool {
	if p.elem is rosie.GroupPattern { return false }
	if p.elem is rosie.DisjunctionPattern { return false }
	return p.is_standard() || orig.is_standard()
}

fn (mut e Expander) merge_charsets(mut p1 rosie.Pattern, mut p2 rosie.Pattern) bool {
	if p1.is_standard() == false { return false }
	if p2.is_standard() == false { return false }

	mut p1_elem := p1.elem
	if mut p1_elem is rosie.LiteralPattern {
		if p1_elem.text.len == 1 {
			mut cs := rosie.new_charset()
			cs.set_char(p1_elem.text[0])
			p1_elem = rosie.CharsetPattern{ cs: cs }
		} else {
			return false
		}
	}

	mut p2_elem := p2.elem
	if mut p2_elem is rosie.LiteralPattern {
		if p2_elem.text.len == 1 {
			mut cs := rosie.new_charset()
			cs.set_char(p2_elem.text[0])
			p2_elem = rosie.CharsetPattern{ cs: cs }
		} else {
			return false
		}
	}

	if mut p1_elem is rosie.CharsetPattern {
		if mut p2_elem is rosie.CharsetPattern {
			p1_elem.cs.merge_or_modify(p2_elem.cs)
			p1.elem = p1_elem
			return true
		}
	}
	return false
}

// expand_pattern Expand the pattern provided
fn (mut e Expander) expand_pattern(orig rosie.Pattern) ? rosie.Pattern {
	//eprintln("Expand pattern='${orig.repr()}'; current='$e.current.name'")
	mut pat := e.group_per_operator(orig)

	match mut pat.elem {
		rosie.LiteralPattern { }
		rosie.CharsetPattern {
			count, ch := pat.elem.cs.count()
			if count == 1 {
				pat.elem = rosie.LiteralPattern{ text: ch.ascii_str() }
			}
		}
		rosie.GroupPattern {
			if pat.elem.word_boundary == true {
				pat = e.expand_tokens(pat)
			}

			mut ar := []rosie.Pattern{}
			for p in pat.elem.ar {
				x := e.expand_pattern(p)?
				ar << x
			}

			if ar.len == 1 {
				ar[0].operator = .sequence
			}

			pat.elem = rosie.GroupPattern{ word_boundary: pat.elem.word_boundary, ar: ar }
		}
		rosie.DisjunctionPattern {
			mut ar := []rosie.Pattern{ cap: pat.elem.ar.len }
			for p in pat.elem.ar {
				mut x := e.expand_pattern(p)?
				if ar.len == 0 || e.merge_charsets(mut ar[ar.len - 1], mut x) == false {
					ar << x
				}
			}

			if ar.len == 1 {
				ar[0].operator = .sequence
			}

			if ar.len == 1 && pat.is_standard() {
				pat = ar[0]
			} else if ar.len == 1 && ar[0].is_standard() {
				pat.elem = ar[0].elem
			} else {
				pat.elem = rosie.DisjunctionPattern{ negative: pat.elem.negative, ar: ar }
			}
		}
		rosie.NamePattern {
			//eprintln("pat.elem.name='$pat.elem.name', e.current: ${e.current.name}")
			mut b := e.current.get(pat.elem.name) or {
				e.current.print_bindings()
				return err
			}
			//eprintln("expand: NamePattern: binding: ${b.repr()}")
			if b.full_name() in e.recursions {
				if e.debug > 2 { eprintln("Detected recursion: '${b.full_name()}'") }
				b.func = true	// TODO doesn't seem to have an effect
				b.recursive = true
			} else {
				// Note: very explicitely, aliases are NOT replaced. They are only expanded.
				new_pat := e.expand(pat.elem.name)?

				if e.unit_test == false && b.alias == true && e.suitable_for_expansion(orig, new_pat) {
					if orig.is_standard() {
						pat = new_pat
					} else {
						pat.elem = new_pat.elem
					}
				}
			}
		}
		rosie.EofPattern { }
		rosie.MacroPattern {
			// Remove the outer GroupPattern
			//eprintln("pat.elem.name: $pat.elem.name")
			inner_pat := e.expand_pattern(pat.elem.pat)?

			// TODO this is rather hard-coded. Can we make this more flexible?
			match pat.elem.name {
				"tok" {
					pat = e.expand_tok_macro(inner_pat)
				}
				"or" {
					pat = e.expand_or_macro(inner_pat)
					pat = e.expand_pattern(pat)?
				}
				"ci" {
					pat = e.make_pattern_case_insensitive(inner_pat)?
				}
				"find", "keepto", "findall" {
					pat = e.expand_find_macro(pat.elem.name, inner_pat)
				}
				"backref" {
					if inner_pat.elem is rosie.GroupPattern {
						if inner_pat.elem.ar.len == 1 && inner_pat.is_standard() {
							pat.elem = rosie.MacroPattern{ name: pat.elem.name, pat: inner_pat.elem.ar[0] }
						}
					}
				}
				"halt" {
					if e.unit_test {
						// Disable 'halt' for unit-tests
						pat.elem = rosie.GroupPattern{ word_boundary: false, ar: [inner_pat] }
					} else {
						pat.elem = rosie.MacroPattern{ name: pat.elem.name, pat: inner_pat }
					}
				}
				else {
					pat.elem = rosie.MacroPattern{ name: pat.elem.name, pat: inner_pat }
				}
			}
		}
		rosie.FindPattern {
			inner_pat := e.expand_pattern(pat.elem.pat)?
			pat.elem = rosie.FindPattern{ keepto: pat.elem.keepto, pat: inner_pat }
		}
		rosie.NonePattern {
		}
	}

	return pat
}

fn (mut e Expander) group_per_operator(orig rosie.Pattern) rosie.Pattern {
	if orig.elem is rosie.GroupPattern {
		op := orig.elem.ar[0].operator
		if orig.elem.ar.any(it.operator != op) == false {
			return orig
		}

		mut root := []rosie.Pattern{}
		mut last_op := rosie.OperatorType.sequence
		for p in orig.elem.ar {
			if last_op != p.operator && p.operator == .choice {
				mut pp := p
				pp.operator = .sequence
				root << rosie.Pattern{ elem: rosie.DisjunctionPattern{ ar: [pp] }}
			} else if p.operator == .choice || last_op == .choice {
				mut ar := &(root.last().elem as rosie.DisjunctionPattern).ar
				mut pp := p
				pp.operator = .sequence
				ar << pp
			} else {
				root << p
			}
			last_op = p.operator
		}

		mut pat := orig
		if root.len == 1 && e.suitable_for_expansion(root[0], orig) {
			pat.elem = root[0].elem
		} else {
			pat.elem = rosie.GroupPattern{ word_boundary: false, ar: root }
		}

		return pat
	}

	return orig
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
			mut b := e.current.get(orig.elem.name)?
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
		rosie.NonePattern { }
	}

	return pat
}

fn (mut e Expander) expand_tok_macro(orig rosie.Pattern) rosie.Pattern {
	if orig.elem is rosie.GroupPattern {
		if orig.elem.ar.len == 1 {
			return e.expand_tokens(orig.elem.ar[0])
		}
	}
	return orig
}

fn (mut e Expander) expand_tokens(orig rosie.Pattern) rosie.Pattern {
	//eprintln("expand_tokens:  IN: ${orig.repr()}")
	if orig.elem is rosie.GroupPattern {
		mut ar := []rosie.Pattern{}
		for p in orig.elem.ar {
			ar << p
			ar << rosie.Pattern{ elem: rosie.NamePattern{ name: "~" } }
		}

		mut pat := rosie.Pattern{ elem: rosie.GroupPattern{ word_boundary: false, ar: [
			rosie.Pattern{ elem: rosie.NamePattern{ name: "~" } },
			rosie.Pattern{ elem: rosie.GroupPattern{ word_boundary: false, ar: ar }}
		] } }

		if orig.min == 0 {
			pat.min = 0
			pat.max = 1
		}

		if orig.max != 1 {
			if mut pat.elem is rosie.GroupPattern {
				pat.elem.ar[1].min = orig.min
				pat.elem.ar[1].max = orig.max
			}
		}

		//eprintln("expand_tokens: OUT-2: ${pat.repr()}")
		return pat
	}

	//eprintln("expand_tokens: OUT-3: ${orig.repr()}")
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

fn (mut e Expander) eliminate_layer(orig rosie.Pattern) rosie.Pattern {
/*
	if orig.elem is rosie.GroupPattern {
		if orig.elem.ar.len == 1 && orig.is_standard() {
			return e.eliminate_layer(orig.elem.ar[0])
		}
	} else if orig.elem is rosie.DisjunctionPattern {
		if orig.elem.ar.len == 1 && orig.is_standard() {
			return e.eliminate_layer(orig.elem.ar[0])
		}
	}
*/
	return orig
}
