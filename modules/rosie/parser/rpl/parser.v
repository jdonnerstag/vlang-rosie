module rpl


import os
import rosie
import rosie.runtime_v2 as rt
import rosie.compiler_vm_backend as compiler

struct Parser {
pub:
	rplx rt.Rplx
	debug int
	import_path []string

pub mut:
	package_cache &PackageCache
	package string		// The current variable context
	grammar string		// Set if anywhere between 'grammar' .. 'end'

	parents []Pattern
	recursions []string		// Detect recursions

	m rt.Match
}

pub fn init_libpath() ? []string {
	rosie := rosie.init_rosie()?
	return rosie.libpath
}

[params]	// TODO A little sad that V-lang requires this hint, rather then the language being properly designed
pub struct ParserOptions {
	package string = "main"
	debug int
	package_cache &PackageCache = &PackageCache{}
}

pub fn new_parser(args ParserOptions) ?Parser {
	rpl := os.read_file('./rpl/rosie/rpl_1_3_jdo.rpl')?
	rplx := compiler.parse_and_compile(rpl: rpl, name: "rpl_module")?

	mut parser := Parser {
		rplx: rplx
		debug: args.debug
		package_cache: args.package_cache
		package: args.package
		import_path: init_libpath()?
	}

	parser.package_cache.add_package(name: args.package, fpath: args.package)?

	// Add builtin package, if not already present
	parser.package_cache.add_builtin()

	return parser
}

pub fn (mut p Parser) find_symbol(name string) ? int {
	return p.m.rplx.symbols.find(name)
}

struct ASTModule { }
struct ASTPackageDecl { name string }
struct ASTIdentifier { name string }
struct ASTOpenBrace { }			// { }
struct ASTCloseBrace { }
struct ASTOpenBracket { }		// [ ]
struct ASTCloseBracket { }
struct ASTOpenParenthesis{ }	// ( )
struct ASTCloseParenthesis { }
struct ASTOperator { op byte }
struct ASTLiteral { str string }
struct ASTCharList { str string }

struct ASTBinding {
	name string
	alias bool
	local bool
}

struct ASTLanguageDecl {
	major int
	minor int
}

struct ASTRange {
	first byte
	last byte
}

struct ASTQuantifier {
	low int
	high int
}

type ASTElem =
	ASTModule |
	ASTLanguageDecl |
	ASTPackageDecl |
	ASTBinding |
	ASTIdentifier |
	ASTRange |
	ASTQuantifier |
	ASTOpenBrace |
	ASTCloseBrace |
	ASTOpenBracket |
	ASTCloseBracket |
	ASTOpenParenthesis |
	ASTCloseParenthesis |
	ASTOperator |
	ASTLiteral |
	ASTCharList


pub fn (mut p Parser) parse(rpl string, debug int) ? {
	ast := p.parse_into_ast(rpl, debug)?

	p.construct_bindings(ast)?

	p.expand_word_boundary(mut p.package())?

	p.package().print_bindings()
}

pub fn (mut p Parser) parse_into_ast(rpl string, debug int) ? []ASTElem {
	data := os.read_file(rpl) or { rpl }
	p.m = rt.new_match(p.rplx, 0)
	p.m.vm_match(data)

	module_idx := p.find_symbol("rpl_1_3.rpl_module")?
	language_decl_idx := p.find_symbol("rpl_1_3.language_decl")?
	major_idx := p.find_symbol("rpl_1_3.major")?
	minor_idx := p.find_symbol("rpl_1_3.minor")?
	package_decl_idx := p.find_symbol("rpl_1_3.package_decl")?
	package_name_idx := p.find_symbol("rpl_1_3.packagename")?
	binding_idx := p.find_symbol("rpl_1_3.grammar-2.binding")?
	import_idx := p.find_symbol("rpl_1_3.import_decl")?
	identifier_idx := p.find_symbol("rpl_1_3.identifier")?
	range_idx := p.find_symbol("rpl_1_3.range")?
	range_first_idx := p.find_symbol("rpl_1_3.range_first")?
	range_last_idx := p.find_symbol("rpl_1_3.range_last")?
	quantifier_idx := p.find_symbol("rpl_1_3.quantifier")?
	low_idx := p.find_symbol("rpl_1_3.low")?
	high_idx := p.find_symbol("rpl_1_3.high")?
	openraw_idx := p.find_symbol("rpl_1_3.openraw")?
	closeraw_idx := p.find_symbol("rpl_1_3.closeraw")?
	literal_idx := p.find_symbol("rpl_1_3.literal")?
	operator_idx := p.find_symbol("rpl_1_3.operator")?
	star_idx := p.find_symbol("rpl_1_3.star")?
	question_idx := p.find_symbol("rpl_1_3.question")?
	plus_idx := p.find_symbol("rpl_1_3.plus")?
	charlist_idx := p.find_symbol("rpl_1_3.charlist")?
	alias_idx := p.find_symbol("rpl_1_3.grammar-2.alias_")?
	local_idx := p.find_symbol("rpl_1_3.grammar-2.local_")?

	//p.m.print_capture_level(0)

	mut ar := []ASTElem{ cap: p.m.captures.len / 8 }

	// See https://github.com/vlang/v/issues/12411 for a V-bug on iterators
	mut iter := p.m.captures.my_filter(pos: 0, level: 0, any: false)
	for {
		cap := iter.next() or { break }

		match cap.idx {
			module_idx {
				ar << ASTModule{}
			}
			language_decl_idx {
				major_cap := iter.next() or { break }
				minor_cap := iter.next() or { break }
				if major_cap.idx != major_idx {
					p.m.print_capture_level(0)
					return error("RPL parser: expected to find 'rpl_1_3.major' at ${iter.last()}, but found ${p.m.capture_str(cap)}")
				}
				if minor_cap.idx != minor_idx {
					p.m.print_capture_level(0)
					return error("RPL parser: expected to find 'rpl_1_3.minor' at ${iter.last()}, but found ${p.m.capture_str(cap)}")
				}
				major := p.m.get_capture_input(major_cap).int()
				minor := p.m.get_capture_input(minor_cap).int()
				ar << ASTLanguageDecl{ major: major, minor: minor }
			}
			package_decl_idx {
				name_cap := iter.next() or { break }
				if name_cap.idx != package_name_idx {
					p.m.print_capture_level(0)
					return error("RPL parser: expected to find 'rpl_1_3.packagename' at ${iter.last()}, but found ${p.m.capture_str(cap)}")
				}
				name := p.m.get_capture_input(name_cap)
				ar << ASTPackageDecl{ name: name }
			}
			binding_idx {
				mut alias := false
				if next_cap := iter.peek_next() {
					if next_cap.idx == alias_idx {
						alias = true
						iter.next() or { break }
					}
				}

				mut local := false
				if next_cap := iter.peek_next() {
					if next_cap.idx == local_idx {
						local = true
						iter.next() or { break }
					}
				}

				identifier_cap := iter.next() or { break }
				if identifier_cap.idx != identifier_idx {
					p.m.print_capture_level(0)
					return error("RPL parser: expected to find 'rpl_1_3.identifier' at ${iter.last()}, but found ${p.m.capture_str(cap)}")
				}
				name := p.m.get_capture_input(identifier_cap)
				ar << ASTBinding{ name: name, alias: alias, local: local }
			}
			range_idx {
				first_cap := iter.next() or { break }
				last_cap := iter.next() or { break }
				if first_cap.idx != range_first_idx {
					p.m.print_capture_level(0)
					return error("RPL parser: expected to find 'rpl_1_3.range_first' at ${iter.last()}, but found ${p.m.capture_str(cap)}")
				}
				if last_cap.idx != range_last_idx {
					p.m.print_capture_level(0)
					return error("RPL parser: expected to find 'rpl_1_3.range_last' at ${iter.last()}, but found ${p.m.capture_str(cap)}")
				}
				first := p.m.get_capture_input(first_cap)[0]
				last := p.m.get_capture_input(last_cap)[0]
				ar << ASTRange{ first: first, last: last }
			}
			quantifier_idx {
				next_cap := iter.next() or { break }
				if next_cap.idx == star_idx {
					ar << ASTQuantifier{ low: 0, high: -1 }
				} else if next_cap.idx == question_idx {
					ar << ASTQuantifier{ low: 0, high: 1 }
				} else if next_cap.idx == plus_idx {
					ar << ASTQuantifier{ low: 1, high: -1 }
				} else {
					low_cap := next_cap
					if low_cap.idx != low_idx {
						p.m.print_capture_level(0)
						return error("RPL parser: expected to find 'rpl_1_3.low' at ${iter.last()}, but found ${p.m.capture_str(cap)}")
					}
					low := p.m.get_capture_input(low_cap).int()

					mut high := -1
					if high_cap := iter.peek_next() {
						if high_cap.idx == high_idx {
							high = p.m.get_capture_input(high_cap).int()
							iter.next() or { break }
						}
					}
					ar << ASTQuantifier{ low: low, high: high }
				}
			}
			openraw_idx {
				ar << ASTOpenBrace{}
			}
			closeraw_idx {
				ar << ASTCloseBrace{}
			}
			literal_idx {
				str := p.m.get_capture_input(cap)
				ar << ASTLiteral{ str: str }
			}
			operator_idx {
				str := p.m.get_capture_input(cap)
				ar << ASTOperator{ op: str[0] }
			}
			charlist_idx {
				str := p.m.get_capture_input(cap)
				ar << ASTCharList{ str: str }
			}
			identifier_idx {
				str := p.m.get_capture_input(cap)
				ar << ASTIdentifier{ name: str }
			}
			else {
				p.m.print_capture_level(0)
				return error("RPL parser: missing implementation for pos: ${iter.last()}: '${p.m.capture_str(cap)}'")
			}
		}
	}

	eprintln("Finished: generated $ar.len AST elements out of $p.m.captures.len captures")
	return ar
}

pub fn (mut p Parser) construct_bindings(ast []ASTElem) ? {
	mut groups := []&GroupElem{}

	for i := 0; i < ast.len; i++ {
		elem := ast[i]
		eprintln("$i: $elem")

		match elem {
			ASTModule {
				// skip
			}
			ASTLanguageDecl {
				// skip
			}
			ASTPackageDecl {
				p.package().name = elem.name
				p.package = elem.name
			}
			ASTBinding {
				mut pkg := p.package()
				pkg.add_binding(name: elem.name, package: p.package, public: !elem.local, alias: elem.alias)?
				mut pattern := &pkg.bindings.last().pattern
				pattern.elem = GroupPattern{ word_boundary: true }
				groups.clear()
				groups << pattern.is_group()?
			}
			ASTIdentifier {
				groups.last().ar << Pattern { elem: NamePattern{ name: elem.name } }
			}
			ASTRange {
				mut cs := rt.new_charset()
				for j := elem.first; j <= elem.last; j++ {
					cs.set_char(j)
				}
				groups.last().ar << Pattern { elem: CharsetPattern{ cs: cs } }
			}
			ASTQuantifier {
				mut last := groups.last().ar.last()
				last.min = elem.low
				last.max = elem.high
			}
			ASTOpenBrace {
				groups.last().ar << Pattern { elem: GroupPattern{ word_boundary: false } }
				groups << groups.last().ar.last().is_group()?
			}
			ASTOpenBracket {
				groups.last().ar << Pattern { elem: DisjunctionPattern{ negative: false } }
				groups << groups.last().ar.last().is_group()?
			}
			ASTOpenParenthesis {
				groups.last().ar << Pattern { elem: GroupPattern{ word_boundary: true } }
				groups << groups.last().ar.last().is_group()?
			}
			ASTCloseBrace, ASTCloseBracket, ASTCloseParenthesis {
				groups.pop()
			}
			ASTOperator {
				mut group := groups.last()
				last := group.ar.last()
				if elem.op == `/` {
					if group is GroupPattern {
						pat := group.ar.pop()
						group.ar << Pattern { elem: DisjunctionPattern{ ar: [pat] } }
						groups << groups.last().ar.last().is_group()?
					}
				} else if elem.op == `&` {	// TODO p & q == {>p q}
					if group is DisjunctionPattern {
						pat := group.ar.pop()
						group.ar << Pattern { elem: GroupPattern{ ar: [pat] } }
						groups << groups.last().ar.last().is_group()?
					}
				} else {
					return error("RPL parser: invalid operator: '$elem.op'")
				}
			}
			ASTLiteral {
				groups.last().ar << Pattern { elem: LiteralPattern{ text: elem.str } }
			}
			ASTCharList {
				mut cs := rt.new_charset_from_rpl(elem.str)
				groups.last().ar << Pattern { elem: CharsetPattern{ cs: cs } }
			}
		}
	}
}

fn (p Parser) expand_word_boundary(mut pkg Package)? {
	for mut b in pkg.bindings {
		p.expand_walk_word_boundary(mut b.pattern)
	}
}

// expand_walk_word_boundary Recursively walk the pattern and all of its
// '(..)', '{..}' and '[..]' groups. Transform all '(..)' into '{pat ~ pat ..}'
// and thus eliminate '(..)'.
fn (p Parser) expand_walk_word_boundary(mut pat Pattern) {
	mut group := pat.is_group() or { return }
	for mut pat_child in group.ar {
		if _ := pat_child.is_group() {
			p.expand_walk_word_boundary(mut pat_child)
		}
	}

	// Replace '(..)' with '{pat ~ ..}'
	p.expand_word_boundary_group(mut pat)

	// If a group has only 1 element, then ignore the group
	if pat.min == 1 && pat.max == 1 && pat.predicate == .na {
		if gr := pat.is_group() {
			if gr.ar.len == 1 {
				pat = gr.ar[0]
			}
		}
	}
}

// expand_word_boundary_group If 'pat' is a GroupPattern with word_boundary == true,
// then transform it to '{pat ~ pat ~ ..}'. So that the compiler does not need to
// worry about the difference between '(..)' and '{..}'. The compiler will only ever
// see '{..}'.
fn (p Parser) expand_word_boundary_group(mut pat Pattern) {
	group := pat.elem
	if group is GroupPattern {
		if group.word_boundary == true {
			mut elem := GroupPattern{ word_boundary: false }
			for i, e in group.ar {
				elem.ar << e

				// Do not add '~' after the last element in the group, except if the quantifier
				// defines that potentially more then 1 must be matched. E.g. '("x")+'
				// must translate into '{"x" ~}+'
				if ((i + 1) < group.ar.len) || (e.min > 1) || (e.max > 1) || (e.max == -1) {
					elem.ar << Pattern { elem: NamePattern{ name: "~" } }
				}
			}

			pat.elem = elem
		}
	}
}
