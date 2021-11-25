module rpl

import os
import rosie
import rosie.parser.core_0 as parser
import rosie.compiler_vm_backend as compiler
import rosie.runtime_v2 as rt

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
struct ASTCharset { cs rosie.Charset }
struct ASTGrammarBlock { mode int }

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
	ASTImport |
	ASTGrammarBlock


// Parser By default new parsers are used to parse the user provided RPL and for each 'import'.
// The idea is that it will enable parallel execution in the future.
// For testing purposes though, you may invoke parse() multiple times.
struct Parser {
pub:
	rplx rt.Rplx			// This is the byte code of the rpl-parser itself !!
	import_path []string	// Where to search for "imports"
	debug int

pub mut:
	file string				// The file being parsed (vs. command line)
	main rosie.Package		// Receiver package if package = ''

mut:
	cli_mode bool			// True if pattern is an expression (cli), else a module (file)
	package string			// The package that will receive the bindings being parsed.
	grammar string			// Set if parser is anywhere between 'grammar' and 'end'
	grammar_private bool	// true, if in between grammar .. in. Bindings are private to the grammar.
	package_cache &rosie.PackageCache	// Packages already imported
	m rt.Match				// The RPL runtime to parse the user provided pattern (eat your own dog food)
	recursions []string		// Temp variable required for expand()
}

pub fn init_libpath() ? []string {
	rosie := rosie.init_rosie()?
	return rosie.libpath
}

const (
	core_0_rpl_fpath = "./rpl/rosie/rpl_1_3_jdo.rpl"
	core_0_rpl_module = "rpl_module"
	core_0_rpl_expression = "rpl_expression"
)

[params]	// TODO A little sad that V-lang requires this hint, rather then the language being properly designed
pub struct CreateParserOptions {
	debug int
	package_cache &rosie.PackageCache = &rosie.PackageCache{}
	libpath []string = init_libpath()?
}

pub fn new_parser(args CreateParserOptions) ?Parser {
	// We are using the core_0 parser to parse the rpl-1.3 RPL pattern, which
	// we then use to parse the user's rpl pattern.
	core_0_rpl := os.read_file(core_0_rpl_fpath)?

	mut core_0_parser := parser.new_parser(debug: 0)?
	core_0_parser.parse(data: core_0_rpl)?

	mut c := compiler.new_compiler(core_0_parser, false, 0)

	c.parser.expand(core_0_rpl_module)?
	c.compile(core_0_rpl_module)?

	c.parser.expand(core_0_rpl_expression)?
	c.compile(core_0_rpl_expression)?

	mut parser := Parser {
		rplx: c.rplx
		debug: args.debug
		package_cache: args.package_cache
		import_path: args.libpath
	}

	parser.package_cache.add_builtin()

	return parser
}

pub fn (p Parser) clone() Parser {
	return Parser {
		rplx: p.rplx
		debug: p.debug
		main: rosie.Package{}
		package_cache: p.package_cache
		import_path: p.import_path
	}
}

// TODO not yet used ?!?! See core_0 parser
[params]
pub struct ParserOptions {
	file string			// If Rpl comes from a file ... (e.g. 'import' statments)
	data string	    	// If Rpl is provided directly (source code, command line, ..)
	module_mode bool	// Mainly for test purposes. If true, treat data as if read from file
}

// parse Parse the user provided pattern. Every parser has an associated package
// which receives the parsed statements. An RPL "import" statement will leverage
// a new parser rosie. Packages are shared the parsers.
pub fn (mut p Parser) parse(args ParserOptions) ? {
	if args.file.len > 0 && args.data.len > 0 {
		return error("${@FN}: Please provide either 'file' or 'data', but not both.")
	}

	p.file = args.file

	// Read the file content, if a file name has been provided
	data := if args.file.len > 0 {
		os.read_file(args.file)?
	} else {
		args.data
	}

	entrypoint := if args.file.len > 0 || args.module_mode == true {
		core_0_rpl_module
	} else {
		core_0_rpl_expression
	}

	// Transform the captures into an ASTElem stream
	ast := p.parse_into_ast(data, entrypoint)?

	// Read the ASTElem stream and create bindings and pattern from it
	p.construct_bindings(ast)?

	// Replace "(p q)" with "{p ~ q}""
	p.expand_word_boundary(mut p.package())?
	p.expand_word_boundary(mut p.package_cache.builtin()? )?

	if args.module_mode {
		if p.main.name.len == 0 { p.main.name = p.file }
		p.main.fpath = p.file
		eprintln("Add package to cache: $p.main.name, $p.main.fpath")
		p.package_cache.add_package(p.main)?	// TODO may be rename add_package() to add(). Though add_package() can be found more easily
	}

	// Just for debugging
	p.package().print_bindings()
}

pub fn (mut p Parser) find_symbol(name string) ? int {
	return p.m.rplx.symbols.find(name)
}

pub fn (mut p Parser) parse_into_ast(rpl string, entrypoint string) ? []ASTElem {
	data := os.read_file(rpl) or { rpl }
	p.m = rt.new_match(rplx: p.rplx, entrypoint: entrypoint, debug: 0)		// TODO Define (only) the captures needed in the match, and ignore the *.rpl definition
	p.m.vm_match(data)?	// Parse the user provided pattern

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
	assignment_prefix_idx := p.find_symbol("rpl_1_3.assignment_prefix")?
	grammar_block_1_idx := p.find_symbol("rpl_1_3.grammar-2.grammar_block_1")?
	grammar_block_2_idx := p.find_symbol("rpl_1_3.grammar-2.grammar_block_2")?
	grammar_end_idx := p.find_symbol("rpl_1_3.end_token")?
	grammar_in_idx := p.find_symbol("rpl_1_3.grammar-2.in_kw")?
	term_idx := p.find_symbol("rpl_1_3.grammar-2.term") or { -1 }

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
			term_idx {
				// skip
			}
			language_decl_idx {
				major_cap := iter.next() or { break }
				minor_cap := iter.next() or { break }
				if major_cap.idx != major_idx {
					p.m.print_capture_level(0, last: iter.last())
					return error("RPL parser: expected to find 'rpl_1_3.major' at ${iter.last()}, but found ${p.m.capture_str(cap)}")
				}
				if minor_cap.idx != minor_idx {
					p.m.print_capture_level(0, last: iter.last())
					return error("RPL parser: expected to find 'rpl_1_3.minor' at ${iter.last()}, but found ${p.m.capture_str(cap)}")
				}
				major := p.m.get_capture_input(major_cap).int()
				minor := p.m.get_capture_input(minor_cap).int()
				ar << ASTLanguageDecl{ major: major, minor: minor }
			}
			package_decl_idx {
				name_cap := iter.next() or { break }
				if name_cap.idx != package_name_idx {
					p.m.print_capture_level(0, last: iter.last())
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
						p.m.print_capture_level(0, last: iter.last())
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

				mut cs := rosie.new_charset()
				if next_cap.idx == charlist_idx {
					str := p.m.get_capture_input(next_cap)
					cs.from_rpl(str)
				} else if next_cap.idx == named_charset_idx {
					str := p.m.get_capture_input(next_cap)
					cs = rosie.known_charsets[str] or {
						return error("RPL parser: invalid charset name: '$str'")
					}
				} else {
					p.m.print_capture_level(0, last: iter.last())
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
						p.m.print_capture_level(0, last: iter.last())
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
				ar << ASTLiteral{ str: unescape(str) }
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
					p.m.print_capture_level(0, any: true, last: iter.last())
					return error("RPL parser: Expected 'identifier' capture: ${p.m.capture_str(cap)}")
				}

				str := p.m.get_capture_input(next_cap)
				ar << ASTMacro{ name: str }
			}
			macro_end_idx {
				ar << ASTMacroEnd{ }
			}
			grammar_block_1_idx {
				ar << ASTGrammarBlock{ mode: 1 }
			}
			grammar_block_2_idx {
				ar << ASTGrammarBlock{ mode: 2 }
			}
			grammar_in_idx {
				ar << ASTGrammarBlock{ mode: 3 }
			}
			grammar_end_idx {
				ar << ASTGrammarBlock{ mode: 0 }
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
			assignment_prefix_idx {
				// "Remove" captures, which we do not need or want.
				// TODO Unfortunately there is no way in RPL to define this.
				iter.skip_subtree()
			}
			syntax_error_idx {
				p.m.print_capture_level(0, any: true, last: iter.last())
				return error("RPL parser at ${iter.last()}: ${p.m.capture_str(cap)}")	// TODO improve with line-no etc.
			}
			else {
				p.m.print_capture_level(0, last: iter.last())
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
	mut groups := []&rosie.GroupElem{}

	mut predicate := rosie.PredicateType.na
	mut predicate_idx := 0

	for i := 0; i < ast.len; i++ {
		elem := ast[i]
		if p.debug > 70 {
			eprintln(elem)
		}

		if i > predicate_idx {
			predicate = rosie.PredicateType.na
		}

		match elem {
			ASTModule {
				// skip
			}
			ASTLanguageDecl {
				p.package().language = "${elem.major}.${elem.minor}"
			}
			ASTPackageDecl {
				if _ := p.package_cache.get_idx(elem.name) {
					return error("Package '$elem.name' already exists in the cache")
				}
				p.main.name = elem.name
				p.package = elem.name
			}
			ASTGrammarBlock {
				if elem.mode == 1 {
					// grammar .. in .. end
					// First block: grammar .. in. Bindings are private to the grammar package,
					// and are allowed to be recursive
					pkg := p.package_cache.add_grammar(p.package)?
					p.grammar = pkg.name
					p.grammar_private = true
				} else if elem.mode == 2 {
					// grammar .. end
					// Bindings are added to the parent package, and are allowed to be recursive
					pkg := p.package_cache.add_grammar(p.package)?
					p.grammar = pkg.name
					p.grammar_private = false
				} else if elem.mode == 3 {
					// Begin of grammar "in"-block
					// Bindings are added to the parent package, but are able to access all bindings
					// in the grammar. And can be recursive.
				} else if elem.mode == 0 {
					// "end" token
					p.grammar = ""
					p.grammar_private = false
				} else {
					panic("Invalid value for 'mode' in ASTGrammarBlock")
				}
			}
			ASTBinding {
				mut idx := 0
				mut pkg := p.package()
				if elem.builtin == false {
					idx = pkg.add_binding(name: elem.name, package: pkg.name, public: !elem.local, alias: elem.alias, grammar: p.grammar)?
				} else {
					pkg = p.package_cache.builtin()?
					idx = pkg.get_idx(elem.name)
					if idx == -1  {
						idx = pkg.add_binding(name: elem.name, package: pkg.name, public: !elem.local, alias: elem.alias)?
					}
				}

				mut pattern := &pkg.bindings[idx].pattern
				pattern.elem = rosie.GroupPattern{ word_boundary: true }

				groups.clear()
				groups << pattern.is_group()?
			}
			ASTIdentifier {
				groups.last().ar << rosie.Pattern { elem: rosie.NamePattern{ name: elem.name }, predicate: predicate }
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
				groups.last().ar << rosie.Pattern { elem: rosie.GroupPattern{ word_boundary: false }, predicate: predicate }
				groups << groups.last().ar.last().is_group()?
			}
			ASTOpenBracket {
				groups.last().ar << rosie.Pattern { elem: rosie.DisjunctionPattern{ negative: elem.complement }, predicate: predicate }
				groups << groups.last().ar.last().is_group()?
			}
			ASTOpenParenthesis {
				groups.last().ar << rosie.Pattern { elem: rosie.GroupPattern{ word_boundary: true }, predicate: predicate }
				groups << groups.last().ar.last().is_group()?
			}
			ASTCloseBrace, ASTCloseParenthesis {
				groups.pop()
			}
			ASTCloseBracket {
				groups.pop()
			}
			ASTOperator {
				mut group := groups.last()
				group.ar.last().operator = p.determine_operator(elem.op)
				if group is rosie.GroupPattern {
					if elem.op == `/` {
						pat := group.ar.pop()
						group.ar << rosie.Pattern { elem: rosie.DisjunctionPattern{ ar: [pat] } }
						groups << groups.last().ar.last().is_group()?
					} else if elem.op == `&` {  // Rpl docs: p & q == {>p q}. We don't do this. We do p & q == {p q}
						// default
					}
				} else if group is rosie.DisjunctionPattern {
					// Will be handled later
				} else {
					return error("RPL parser: invalid operator: '$elem.op'")
				}
			}
			ASTLiteral {
				groups.last().ar << rosie.Pattern { elem: rosie.LiteralPattern{ text: elem.str }, predicate: predicate }
			}
			ASTCharset {
				groups.last().ar << rosie.Pattern { elem: rosie.CharsetPattern{ cs: elem.cs }, predicate: predicate }
			}
			ASTPredicate {
				predicate = p.determine_predicate(elem.str)?
				predicate_idx = i + 1
			}
			ASTMacro {
				mut pat := rosie.Pattern {
					elem: rosie.MacroPattern {
						name: elem.name,
						pat: rosie.Pattern {
							elem: rosie.GroupPattern {
								word_boundary: false
							}
						}
					},
					predicate: predicate
				}

				groups.last().ar << pat
				groups << (pat.elem as rosie.MacroPattern).pat.is_group()?
			}
			ASTMacroEnd {
				groups.pop()
				mut macro := &(groups.last().ar.last().elem as rosie.MacroPattern)
				//eprintln(macro)
				p.expand_walk_word_boundary(mut macro.pat)
			}
			ASTImport {
				p.import_package(elem.alias, elem.path)?
			}
		}
	}
	p.package_cache.print_stats()
}

fn (p Parser) determine_operator(ch byte) rosie.OperatorType {
	return match ch {
		`/` { rosie.OperatorType.choice }
		`&` { rosie.OperatorType.conjunction }
		else { rosie.OperatorType.sequence }
	}
}

fn (p Parser) determine_predicate(str string) ? rosie.PredicateType {
	mut tok := rosie.PredicateType.na

	for ch in str {
		match ch {
			`!` {
				tok = match tok {
					.na { rosie.PredicateType.negative_look_ahead }
					.look_ahead { rosie.PredicateType.negative_look_ahead }
					.look_behind { rosie.PredicateType.negative_look_ahead }		// See rosie doc
					.negative_look_ahead { rosie.PredicateType.look_ahead }
					.negative_look_behind { rosie.PredicateType.negative_look_ahead }
				}
			}
			`>` {
				tok = match tok {
					.na { rosie.PredicateType.look_ahead }
					.look_ahead { rosie.PredicateType.look_ahead }
					.look_behind { rosie.PredicateType.look_ahead }
					.negative_look_ahead { rosie.PredicateType.negative_look_ahead }
					.negative_look_behind { rosie.PredicateType.look_ahead }
				}
			}
			`<` {
				tok = match tok {
					.na { rosie.PredicateType.look_behind }
					.look_ahead { rosie.PredicateType.look_behind }
					.look_behind { rosie.PredicateType.look_behind }
					.negative_look_ahead { rosie.PredicateType.negative_look_behind }
					.negative_look_behind { rosie.PredicateType.negative_look_behind }
				}
			}
			else {
				return error("RPL parser: invalid predicate: '$str'")
			}
		}
	}

	return tok
}

fn (p Parser) expand_word_boundary(mut pkg rosie.Package)? {
	for mut b in pkg.bindings {
		p.expand_walk_word_boundary(mut b.pattern)
	}
}

// expand_walk_word_boundary Recursively walk the pattern and all of its
// '(..)', '{..}' and '[..]' groups. Transform all '(..)' into '{pat ~ pat ..}'
// and thus eliminate '(..)'.
fn (p Parser) expand_walk_word_boundary(mut pat rosie.Pattern) {
	mut group := pat.is_group() or { return }
	for mut pat_child in group.ar {
		if _ := pat_child.is_group() {
			p.expand_walk_word_boundary(mut pat_child)
		}
	}

	// Replace '(..)' with '{pat ~ ..}'
	p.expand_word_boundary_group(mut pat)

	// Apply & and / operator to charset groups, e.g. [[:digit:] & ![0]]
	if mut pat.elem is rosie.DisjunctionPattern {
		p.merge_charsets(mut pat.elem)
	}

	// If a group has only 1 element, then ignore the group
	p.eliminate_one_group(mut pat)
}

fn (p Parser) merge_charsets(mut elem rosie.DisjunctionPattern) {
	for i := 1; i < elem.ar.len; i++ {
		op := elem.ar[i - 1].operator
		cs1 := elem.ar[i - 1].get_charset() or { continue }
		cs2 := elem.ar[i].get_charset() or { continue }

		cs := match op {
			.sequence { cs1.merge_or(cs2) }
			.choice { cs1.merge_or(cs2) }
			.conjunction { cs1.merge_and(cs2) }
		}
		elem.ar[i - 1].elem = rosie.CharsetPattern{ cs: cs }
		elem.ar.delete(i)
		i --
	}

	if elem.negative && elem.ar.len == 1 {
		elem0 := elem.ar[0].elem
		if elem0 is rosie.CharsetPattern {
			elem.ar[0].elem = rosie.CharsetPattern{ cs: elem0.cs.complement() }
			elem.negative = !elem.negative
		}
	}
}

fn (p Parser) eliminate_one_group(mut pat rosie.Pattern) {
	if pat.min == 1 && pat.max == 1 && pat.predicate == .na {
		if gr := pat.is_group() {
			if gr.ar.len == 1 {
				if pat.elem is rosie.GroupPattern {
					pat.copy_from(gr.ar[0])
				} else if (pat.elem as rosie.DisjunctionPattern).negative == false {
					pat.copy_from(gr.ar[0])
				}
			}
		}
	} else if gr := pat.is_group() {
		if gr.ar.len == 1 {
			e := gr.ar[0]
			if e.min == 1 && e.max == 1 && e.predicate == .na {
				pat.elem = e.elem
			}
		}
	}
}

// expand_word_boundary_group If 'pat' is a GroupPattern with word_boundary == true,
// then transform it to '{pat ~ pat ~ ..}'. So that the compiler does not need to
// worry about the difference between '(..)' and '{..}'. The compiler will only ever
// see '{..}'.
fn (p Parser) expand_word_boundary_group(mut pat rosie.Pattern) {
	group := pat.elem
	if group is rosie.GroupPattern {
		if group.word_boundary == true {
			add_wb := (pat.min > 1) || (pat.max > 1) || (pat.max == -1)
			mut elem := rosie.GroupPattern{ word_boundary: false }
			for i, e in group.ar {
				elem.ar << e

				// Do not add '~' after the last element in the group, except if the quantifier
				// defines that potentially more then 1 must be matched. E.g. '("x")+'
				// must translate into '{"x" ~}+'
				if ((i + 1) < group.ar.len) || add_wb {
					elem.ar << rosie.Pattern { elem: rosie.NamePattern{ name: "~" } }
				}
			}

			pat.elem = elem
		}
	}
}

fn unescape(str string) string {
	if str.index_byte(`\\`) == -1 {
		return str
	}

	mut rtn := []byte{ cap: str.len }
	for i := 0; i < str.len; i++ {
		ch := str[i]
		if ch == `\\` && (i + 1) < str.len {
			rtn << str[i + 1]
			i ++
		} else {
			rtn << ch
		}
	}
	return rtn.bytestr()
}