module rpl


import os
import rosie
import rosie.runtime_v2 as rt
import rosie.compiler_vm_backend as compiler

struct Parser {
pub:
	rplx rt.Rplx		// This is the byte code of the rpl-parser itself !!
	debug int
	import_path []string

pub mut:
	package_cache &PackageCache
	package string		// The current variable context
	grammar string		// Set if anywhere between 'grammar' .. 'end'

	parents []Pattern
	recursions []string	// Detect recursions

	m rt.Match			// The RPL runtime to parse the user provided pattern
}

pub fn init_libpath() ? []string {
	rosie := rosie.init_rosie()?
	return rosie.libpath
}

enum ParserExpressionEnum {
	rpl_module
	rpl_expression
}

[params]	// TODO A little sad that V-lang requires this hint, rather then the language being properly designed
pub struct ParserOptions {
	rpl_type ParserExpressionEnum = .rpl_expression
	package string = "main"
	debug int
	package_cache &PackageCache = &PackageCache{}
}

pub fn new_parser(args ParserOptions) ?Parser {
	pattern_name := match args.rpl_type {
		.rpl_module { "rpl_module" }
		.rpl_expression { "rpl_expression" }
	}

	rpl := os.read_file('./rpl/rosie/rpl_1_3_jdo.rpl')?
	rplx := compiler.parse_and_compile(rpl: rpl, name: pattern_name)?

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
struct ASTMacro { name string }
struct ASTMacroEnd { }
struct ASTOpenBrace { }			// { }
struct ASTCloseBrace { }
struct ASTOpenBracket { complement bool }	// [ ]
struct ASTCloseBracket { }
struct ASTOpenParenthesis{ }	// ( )
struct ASTCloseParenthesis { }
struct ASTOperator { op byte }
struct ASTLiteral { str string }
struct ASTPredicate { str string }
struct ASTCharset { cs rt.Charset }

struct ASTBinding {
	name string
	alias bool
	local bool
	builtin bool
}

struct ASTLanguageDecl {
	major int
	minor int
}

struct ASTQuantifier {
	low int
	high int
}

struct ASTImport {
	path string
	alias string
}

type ASTElem =
	ASTModule |
	ASTLanguageDecl |
	ASTPackageDecl |
	ASTBinding |
	ASTIdentifier |
	ASTQuantifier |
	ASTOpenBrace |
	ASTCloseBrace |
	ASTOpenBracket |
	ASTCloseBracket |
	ASTOpenParenthesis |
	ASTCloseParenthesis |
	ASTOperator |
	ASTLiteral |
	ASTCharset |
	ASTPredicate |
	ASTMacro |
	ASTMacroEnd |
	ASTImport


// parse Parse the user provided pattern. Every parser has an associated package
// which receives the parsed statements. An RPL "import" statement will leverage
// a new parser parser. Packages are shared the parsers.
pub fn (mut p Parser) parse(rpl string) ? {
	ast := p.parse_into_ast(rpl)?

	p.construct_bindings(ast)?

	p.expand_word_boundary(mut p.package())?
	p.expand_word_boundary(mut p.package_cache.builtin()? )?

	p.package().print_bindings()
}

pub fn (mut p Parser) parse_into_ast(rpl string) ? []ASTElem {
	data := os.read_file(rpl) or { rpl }
	p.m = rt.new_match(p.rplx, 0)		// TODO Define (only) the captures needed in the match, and ignore the *.rpl definition
	p.m.vm_match(data)	// Parse the user provided pattern

	// TODO Define enum and preset rplx.symbols so that enum value and symbol table index are the same.
	module_idx := p.find_symbol("rpl_1_3.rpl_module") or { -1 }				// Not available for rpl_expression
	expression_idx := p.find_symbol("rpl_1_3.rpl_expression") or { -2 }		// Not available for rpl_module
	main_idx := p.find_symbol("rpl_1_3.main") or { -3 }						// Not available for rpl_module
	language_decl_idx := p.find_symbol("rpl_1_3.language_decl") or { -4 }	// Not available for rpl_expression
	major_idx := p.find_symbol("rpl_1_3.major") or { -5 }					// Not available for rpl_expression
	minor_idx := p.find_symbol("rpl_1_3.minor") or { -6 }					// Not available for rpl_expression
	package_decl_idx := p.find_symbol("rpl_1_3.package_decl")?
	package_name_idx := p.find_symbol("rpl_1_3.packagename")?
	binding_idx := p.find_symbol("rpl_1_3.binding")?
	importpath_idx := p.find_symbol("rpl_1_3.importpath")?
	identifier_idx := p.find_symbol("rpl_1_3.identifier")?
	//range_idx := p.find_symbol("rpl_1_3.range")?
	//range_first_idx := p.find_symbol("rpl_1_3.range_first")?
	//range_last_idx := p.find_symbol("rpl_1_3.range_last")?
	quantifier_idx := p.find_symbol("rpl_1_3.quantifier")?
	low_idx := p.find_symbol("rpl_1_3.low")?
	high_idx := p.find_symbol("rpl_1_3.high")?
	openraw_idx := p.find_symbol("rpl_1_3.openraw")?
	closeraw_idx := p.find_symbol("rpl_1_3.closeraw")?
	openbracket_idx := p.find_symbol("rpl_1_3.openbracket")?
	open_idx := p.find_symbol("rpl_1_3.open")?
	close_idx := p.find_symbol("rpl_1_3.close")?
	closebracket_idx := p.find_symbol("rpl_1_3.closebracket")?
	literal_idx := p.find_symbol("rpl_1_3.literal")?
	operator_idx := p.find_symbol("rpl_1_3.operator")?
	//star_idx := p.find_symbol("rpl_1_3.star")?
	//question_idx := p.find_symbol("rpl_1_3.question")?
	//plus_idx := p.find_symbol("rpl_1_3.plus")?
	charlist_idx := p.find_symbol("rpl_1_3.charlist")?
	syntax_error_idx := p.find_symbol("rpl_1_3.syntax_error")?
	predicate_idx := p.find_symbol("rpl_1_3.predicate")?
	named_charset_idx := p.find_symbol("rpl_1_3.named_charset")?
	complement_idx := p.find_symbol("rpl_1_3.complement")?
	simple_charset_idx := p.find_symbol("rpl_1_3.simple_charset")?
	modifier_idx := p.find_symbol("rpl_1_3.modifier")?
	macro_idx := p.find_symbol("rpl_1_3.grammar-2.macro")?
	macro_end_idx := p.find_symbol("rpl_1_3.macro_end")?

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
			expression_idx {
				// skip
			}
			main_idx {
				ar << ASTBinding{ name: "*", alias: false, local: false, builtin: false }
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
				if p.m.get_capture_input(cap).starts_with(";") == false {
					mut local_ := false
					mut alias_ := false
					mut builtin_ := false
					for {
						next_cap := iter.peek_next() or { break }
						if next_cap.idx != modifier_idx { break }

						modifier := p.m.get_capture_input(next_cap)
						match modifier {
							"local" { local_ = true }
							"alias" { alias_ = true }
							"builtin" { builtin_ = true }
							else { /* will never happen */ }
						}
						iter.next() or { break }
					}

					identifier_cap := iter.next() or { break }
					if identifier_cap.idx != identifier_idx {
						p.m.print_capture_level(0)
						return error("RPL parser: expected to find 'rpl_1_3.identifier' at ${iter.last()}, but found ${p.m.capture_str(cap)}")
					}
					name := p.m.get_capture_input(identifier_cap)
					ar << ASTBinding{ name: name, alias: alias_, local: local_, builtin: builtin_ }
				}
			}
			simple_charset_idx {
				mut next_cap := iter.next() or { break }
				mut complement := false
				if next_cap.idx == complement_idx {
					complement = true
					next_cap = iter.next() or { break }
				}

				mut cs := rt.new_charset()
				if next_cap.idx == charlist_idx {
					str := p.m.get_capture_input(next_cap)
					cs.from_rpl(str)
				} else if next_cap.idx == named_charset_idx {
					str := p.m.get_capture_input(next_cap)
					cs = rt.known_charsets[str] or {
						return error("RPL parser: invalid charset name: '$str'")
					}
				} else {
					p.m.print_capture_level(0)
					return error("RPL parser: invalid simple_charset capture at ${iter.last()}, but found ${p.m.capture_str(cap)}")
				}

				if complement {
					cs = cs.complement()
				}
				ar << ASTCharset{ cs: cs }
			}
			quantifier_idx {
				mut str := p.m.get_capture_input(cap)
				if str == "*" {
					ar << ASTQuantifier{ low: 0, high: -1 }
				} else if str == "?" {
					ar << ASTQuantifier{ low: 0, high: 1 }
				} else if str == "+" {
					ar << ASTQuantifier{ low: 1, high: -1 }
				} else {
					low_cap := iter.next() or { break }
					if low_cap.idx != low_idx {
						p.m.print_capture_level(0)
						return error("RPL parser: expected to find 'rpl_1_3.low' at ${iter.last()}, but found ${p.m.capture_str(low_cap)}")
					}
					low := p.m.get_capture_input(low_cap).int()

					mut high := low
					if high_cap := iter.peek_next() {
						if high_cap.idx == high_idx {
							iter.next() or { break }
							str = p.m.get_capture_input(high_cap)
							high = if str.len == 0 { -1 } else { str.int() }
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
			open_idx {
				ar << ASTOpenParenthesis{}
			}
			close_idx {
				ar << ASTCloseParenthesis{}
			}
			openbracket_idx {
				mut complement := false
				if next_cap := iter.peek_next() {
					if next_cap.idx == complement_idx {
						complement = true
						iter.next() or { break }
					}
				}

				ar << ASTOpenBracket{ complement: complement }
			}
			closebracket_idx {
				ar << ASTCloseBracket{}
			}
			literal_idx {
				str := p.m.get_capture_input(cap)
				ar << ASTLiteral{ str: str }
			}
			operator_idx {
				str := p.m.get_capture_input(cap)
				ar << ASTOperator{ op: str[0] }
			}
			identifier_idx {
				str := p.m.get_capture_input(cap)
				ar << ASTIdentifier{ name: str }
			}
			predicate_idx {
				str := p.m.get_capture_input(cap)
				ar << ASTPredicate{ str: str }
			}
			macro_idx {
				next_cap := iter.next() or { break }
				if next_cap.idx != identifier_idx {
					p.m.print_capture_level(0, any: true)
					return error("RPL parser: Expected 'identifier' capture: ${p.m.capture_str(cap)}")
				}

				str := p.m.get_capture_input(next_cap)
				ar << ASTMacro{ name: str }
			}
			macro_end_idx {
				ar << ASTMacroEnd{ }
			}
			importpath_idx {
				mut path := p.m.get_capture_input(cap)
				mut alias := path
				if next_cap := iter.peek_next() {
					if next_cap.idx == literal_idx {
						path = p.m.get_capture_input(next_cap)
						iter.next() or { break }
					}
				}

				if next_cap := iter.peek_next() {
					if next_cap.idx == package_name_idx {
						iter.next() or { break }
						alias = p.m.get_capture_input(next_cap)
					}
				}

				ar << ASTImport{ path: path, alias: alias }
			}
			syntax_error_idx {
				p.m.print_capture_level(0, any: true, last: iter.last())
				return error("RPL parser at ${iter.last()}: ${p.m.capture_str(cap)}")	// TODO improve with line-no etc.
			}
			else {
				p.m.print_capture_level(0)
				return error("RPL parser: missing implementation for pos: ${iter.last()}: '${p.m.capture_str(cap)}'")
			}
		}
	}

	eprintln("Finished: generated $ar.len AST elements out of $p.m.captures.len captures")

	if p.debug > 50 {
		p.m.print_capture_level(0, any: p.debug > 90)
	}

	return ar
}

pub fn (mut p Parser) construct_bindings(ast []ASTElem) ? {
	mut groups := []&GroupElem{}

	mut predicate := PredicateType.na
	mut predicate_idx := 0

	for i := 0; i < ast.len; i++ {
		elem := ast[i]
		//eprintln(elem)

		if i > predicate_idx {
			predicate = PredicateType.na
		}

		match elem {
			ASTModule {
				// skip
			}
			ASTLanguageDecl {
				p.package().language = "${elem.major}.${elem.minor}"
			}
			ASTPackageDecl {
				p.package().name = elem.name
				p.package = elem.name
			}
			ASTBinding {
				mut idx := 0
				mut pkg := p.package()
				if elem.builtin == false {
					pkg.add_binding(name: elem.name, package: pkg.name, public: !elem.local, alias: elem.alias)?
					idx = pkg.bindings.len - 1
				} else {
					pkg = p.package_cache.builtin()?
					idx = pkg.get_idx(elem.name)
					if idx == -1  {
						pkg.add_binding(name: elem.name, package: pkg.name, public: !elem.local, alias: elem.alias)?
						idx = pkg.bindings.len - 1
					}
				}

				mut pattern := &pkg.bindings[idx].pattern
				pattern.elem = GroupPattern{ word_boundary: true }

				groups.clear()
				groups << pattern.is_group()?
			}
			ASTIdentifier {
				groups.last().ar << Pattern { elem: NamePattern{ name: elem.name }, predicate: predicate }
			}
			ASTQuantifier {
				// TODO Don't understand why these are not the same
				//mut last := groups.last().ar.last()
				//eprintln("last: $last")
				//last.min = elem.low
				//last.max = elem.high
				groups.last().ar.last().min = elem.low
				groups.last().ar.last().max = elem.high
			}
			ASTOpenBrace {
				groups.last().ar << Pattern { elem: GroupPattern{ word_boundary: false }, predicate: predicate }
				groups << groups.last().ar.last().is_group()?
			}
			ASTOpenBracket {
				groups.last().ar << Pattern { elem: DisjunctionPattern{ negative: elem.complement }, predicate: predicate }
				groups << groups.last().ar.last().is_group()?
			}
			ASTOpenParenthesis {
				groups.last().ar << Pattern { elem: GroupPattern{ word_boundary: true }, predicate: predicate }
				groups << groups.last().ar.last().is_group()?
			}
			ASTCloseBrace, ASTCloseParenthesis {
				groups.pop()
			}
			ASTCloseBracket {
				mut group := groups.pop()
				if group.ar.any(it.elem !is CharsetPattern) == false {
					mut cs := rt.new_charset()
					for pat in group.ar {
						cs = cs.merge_or((pat.elem as CharsetPattern).cs)
					}
					if (groups.last().ar.last().elem as DisjunctionPattern).negative {
						cs = cs.complement()
						mut last := &groups.last().ar.last().elem
						if mut last is DisjunctionPattern { last.negative = false }
					}
					group.ar.clear()
					group.ar << Pattern{ elem: CharsetPattern{ cs: cs }}
				}
			}
			ASTOperator {
				mut group := groups.last()
				if elem.op == `/` {
					if group is GroupPattern {
						pat := group.ar.pop()
						group.ar << Pattern { elem: DisjunctionPattern{ ar: [pat] } }
						groups << groups.last().ar.last().is_group()?
					}
				} else if elem.op == `&` {	// TODO p & q == {>p q}
					if group is DisjunctionPattern {
						// ignore
					}
				} else {
					return error("RPL parser: invalid operator: '$elem.op'")
				}
			}
			ASTLiteral {
				groups.last().ar << Pattern { elem: LiteralPattern{ text: elem.str }, predicate: predicate }
			}
			ASTCharset {
				mut add := true
				if groups.last() is DisjunctionPattern {
					ar := groups.last().ar
					if ar.len > 0 {
						elem2 := ar.last().elem
						if elem2 is CharsetPattern {
							ar.last().elem = CharsetPattern { cs: elem2.cs.merge_or(elem.cs) }
							add = false
						}
					}
				}

				if add {
					groups.last().ar << Pattern { elem: CharsetPattern{ cs: elem.cs }, predicate: predicate }
				}
			}
			ASTPredicate {
				predicate = p.determine_predicate(elem.str)?
				predicate_idx = i + 1
			}
			ASTMacro {
				mut pat := Pattern {
					elem: MacroPattern {
						name: elem.name,
						pat: Pattern {
							elem: GroupPattern {
								word_boundary: false
							}
						}
					},
					predicate: predicate
				}

				groups.last().ar << pat
				groups << (pat.elem as MacroPattern).pat.is_group()?
			}
			ASTMacroEnd {
				groups.pop()
				mut macro := &(groups.last().ar.last().elem as MacroPattern)
				//eprintln(macro)
				p.expand_walk_word_boundary(mut macro.pat)
			}
			ASTImport {
				p.import_package(elem.alias, elem.path)?
			}
		}
	}
}

fn (p Parser) determine_predicate(str string) ? PredicateType {
	mut tok := PredicateType.na

	for ch in str {
		match ch {
			`!` {
				tok = match tok {
					.na { PredicateType.negative_look_ahead }
					.look_ahead { PredicateType.negative_look_ahead }
					.look_behind { PredicateType.negative_look_ahead }		// See rosie doc
					.negative_look_ahead { PredicateType.look_ahead }
					.negative_look_behind { PredicateType.negative_look_ahead }
				}
			}
			`>` {
				tok = match tok {
					.na { PredicateType.look_ahead }
					.look_ahead { PredicateType.look_ahead }
					.look_behind { PredicateType.look_ahead }
					.negative_look_ahead { PredicateType.negative_look_ahead }
					.negative_look_behind { PredicateType.look_ahead }
				}
			}
			`<` {
				tok = match tok {
					.na { PredicateType.look_behind }
					.look_ahead { PredicateType.look_behind }
					.look_behind { PredicateType.look_behind }
					.negative_look_ahead { PredicateType.negative_look_behind }
					.negative_look_behind { PredicateType.negative_look_behind }
				}
			}
			else {
				return error("RPL parser: invalid predicate: '$str'")
			}
		}
	}

	return tok
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
	p.eliminate_one_group(mut pat)
}

fn (p Parser) eliminate_one_group(mut pat Pattern) {
	if pat.min == 1 && pat.max == 1 && pat.predicate == .na {
		if gr := pat.is_group() {
			if gr.ar.len == 1 {
				if pat.elem is GroupPattern {
					pat = gr.ar[0]
				} else if (pat.elem as DisjunctionPattern).negative == false {
					pat = gr.ar[0]
				}
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
			add_wb := (pat.min > 1) || (pat.max > 1) || (pat.max == -1)
			mut elem := GroupPattern{ word_boundary: false }
			for i, e in group.ar {
				elem.ar << e

				// Do not add '~' after the last element in the group, except if the quantifier
				// defines that potentially more then 1 must be matched. E.g. '("x")+'
				// must translate into '{"x" ~}+'
				if ((i + 1) < group.ar.len) || add_wb {
					elem.ar << Pattern { elem: NamePattern{ name: "~" } }
				}
			}

			pat.elem = elem
		}
	}
}
