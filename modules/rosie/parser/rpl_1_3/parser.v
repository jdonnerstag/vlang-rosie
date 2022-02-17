module rpl_1_3

import os
import rosie
import ystrconv
import rosie.runtimes.v2 as rt

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
	file string					// The file being parsed (vs. command line)
	package_cache &rosie.PackageCache
	main &rosie.Package			// The package that will receive the bindings being parsed.
	imports []rosie.ImportStmt	// file path of the imports

mut:
	current &rosie.Package	// Set if parser is anywhere between 'grammar' and 'end'
	cli_mode bool			// True if pattern is an expression (cli), else a module (file)
	grammar string			// Used when adding new bindings.
	m rt.Match				// The RPL runtime to parse the user provided pattern (eat your own dog food)
}

const (
	rpl_1_3_fpath = "./rpl/rosie/rpl_1_3_jdo.rpl"
	rpl_module = "rpl_module"
	rpl_expression = "rpl_expression"
)

fn is_rpl_file_newer(rpl_fname string) bool {
	rplx_fname := rpl_fname + "x"
	if os.is_file(rplx_fname) == false {
		return false
	}

	if os.is_file(rpl_fname) == false {
		return true
	}

	rpl := os.file_last_mod_unix(rpl_fname)
	rplx := os.file_last_mod_unix(rplx_fname)

	if rpl < rplx {
		return true
	}

	eprintln("WARNING: rplx-File is not up-to-date: file=$rpl_fname, rpl=$rpl >= rplx=$rplx")
	return false
}

fn load_rplx(fname string) ? &rt.Rplx {

	// TODO embed the rplx file rather then loading it
	if is_rpl_file_newer(fname) == false {
		panic("Please run 'rosie_cli.exe --norcfile compile -l stage_0 $fname rpl_module rpl_expression' to rebuild the *.rplx file")
	}

	rplx_fname := fname + "x"
	if rplx_fname != "./rpl/rosie/rpl_1_3_jdo.rplx" {
		panic("Currently this is hard-coded. For \$embed_file() we need constant string literal")
	}

	rplx_data := $embed_file("./rpl/rosie/rpl_1_3_jdo.rplx").to_bytes()
	return rt.rplx_load_data(rplx_data)
}

pub fn init_libpath() ? []string {
	rosie := rosie.init_rosie()?
	return rosie.libpath
}

[params]	// TODO A little sad that V-lang requires this hint, rather then the language being properly designed
pub struct CreateParserOptions {
	debug int
	package_cache &rosie.PackageCache = rosie.new_package_cache()
	libpath []string = init_libpath()?
}

pub fn new_parser(args CreateParserOptions) ?Parser {
	// TODO Add timings to each step

	rplx := load_rplx(rpl_1_3_fpath)?

	// TODO May be "" is a better default for name and fpath.
	main := rosie.new_package(name: "main", fpath: "main", parent: args.package_cache.builtin())

	mut parser := Parser {
		rplx: rplx
		debug: args.debug
		main: main
		current: main
		package_cache: args.package_cache
		import_path: args.libpath
	}

	return parser
}

pub fn (p Parser) clone() Parser {
	main := rosie.new_package(name: "main", fpath: "main", parent: p.main.parent)

	return Parser {
		rplx: p.rplx
		debug: p.debug
		main: main
		current: main
		file: ""
		package_cache: p.package_cache
		import_path: p.import_path
	}
}

// parse Parse the user provided pattern. Every parser has an associated package
// which receives the parsed statements. An RPL "import" statement will leverage
// a new parser rosie. Packages are shared the parsers.
pub fn (mut p Parser) parse(args rosie.ParserOptions) ? {
	p.file = args.file
	mut data := args.data

	if data.len == 0 && p.file.len > 0 {
		data = os.read_file(args.file)?
		p.current.fpath = args.file
		p.current.name = args.file.all_before_last(".").all_after_last("/").all_after_last("\\")
	}

	if data.len == 0 {
		return error("Please provide a RPL pattern either via 'data' or 'file' parameter.")
	}

	entrypoint := if args.file.len > 0 || args.module_mode == true {
		rpl_module
	} else {
		rpl_expression
	}

	// Transform the captures into an ASTElem stream
	p.current = p.main
	ast := p.parse_into_ast(data, entrypoint)?

	// Read the ASTElem stream and create bindings and pattern from it
	p.construct_bindings(ast)?
	// p.package().print_bindings()

	if args.ignore_imports == false {
		// This can only work, if the import files have a compliant RPL version.
		// Else, let MasterParser do the import.
		p.import_packages()?
	}

	// Just for debugging
	//p.package().print_bindings()
}

pub fn (mut p Parser) find_symbol(name string) ? int {
	return p.m.rplx.symbols.find(name)
}

pub fn (mut p Parser) parse_into_ast(rpl string, entrypoint string) ? []ASTElem {
	p.m = rt.new_match(rplx: p.rplx, debug: 0)		// TODO Define (only) the captures needed in the match, and ignore the *.rpl definition
	p.m.vm_match(input: rpl, entrypoint: entrypoint)?	// Parse the user provided pattern

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
	charlist_idx := p.find_symbol("rpl_1_3.charlist")?
	syntax_error_idx := p.find_symbol("rpl_1_3.syntax_error")?
	predicate_idx := p.find_symbol("rpl_1_3.predicate")?
	named_charset_idx := p.find_symbol("rpl_1_3.named_charset")?
	complement_idx := p.find_symbol("rpl_1_3.complement")?
	simple_charset_idx := p.find_symbol("rpl_1_3.simple_charset")?
	modifier_idx := p.find_symbol("rpl_1_3.modifier")?
	macro_idx := p.find_symbol("grammar_0.macro")?
	macro_end_idx := p.find_symbol("rpl_1_3.macro_end")?
	assignment_prefix_idx := p.find_symbol("rpl_1_3.assignment_prefix")?
	grammar_block_1_idx := p.find_symbol("grammar_0.grammar_block_1")?
	grammar_block_2_idx := p.find_symbol("grammar_0.grammar_block_2")?
	grammar_end_idx := p.find_symbol("rpl_1_3.end_token")?
	grammar_in_idx := p.find_symbol("grammar_0.in_kw")?
	term_idx := p.find_symbol("grammar_0.term") or { -1 }

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
				p.main.language = "${major}.${minor}"		// TODO there is no need to split it in rpl in major and minor

				if major != 1 {
					return error_with_code(
						"RPL error: the selected parser does not support RPL ${major}.${minor}",
						rosie.err_rpl_version_not_supported
					)
				}

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
				ar << ASTLiteral{ str: unescape(str, true)? }
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

	// eprintln("Finished: generated $ar.len AST elements out of $p.m.captures.len captures")

	if p.debug > 50 {
		p.m.print_capture_level(0, any: p.debug > 90)
	}

	return ar
}

pub fn (mut p Parser) construct_bindings(ast []ASTElem) ? {
	mut groups := []&rosie.GroupElem{}

	mut b := &rosie.Binding(0)
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
			}
			ASTLanguageDecl {
			}
			ASTPackageDecl {
				p.main.name = elem.name
			}
			ASTGrammarBlock {
				name := "grammar_${p.current.imports.len}"
				if elem.mode == 1 {
					// grammar .. in .. end
					// First block: grammar .. in. Bindings are private to the grammar package,
					// and are allowed to be recursive
					p.current = p.current.new_grammar(name)?
					p.grammar = ""
				} else if elem.mode == 2 {
					// grammar .. end
					// Bindings are added to the parent package, and are allowed to be recursive
					p.current.new_grammar(name)?
					p.grammar = name
				} else if elem.mode == 3 {
					// Begin of grammar "in"-block
					// Bindings are added to the parent package, but are able to access all bindings
					// in the grammar. And can be recursive.
					p.grammar = p.current.name
					p.current = p.main
				} else if elem.mode == 0 {
					// "end" token
					p.current = p.main
					p.grammar = ""
				} else {
					panic("Invalid value for 'mode' in ASTGrammarBlock")
				}
			}
			ASTBinding {
				if elem.builtin == false {
					b = p.current.new_binding(name: elem.name, public: !elem.local, alias: elem.alias, grammar: p.grammar)?
				} else {
					mut pkg := p.current.builtin()
					b = pkg.replace_binding(name: elem.name, public: !elem.local, alias: elem.alias)?
				}

				groups.clear()
			}
			ASTIdentifier {
				pat := rosie.Pattern { elem: rosie.NamePattern{ name: elem.name }, predicate: predicate }
				if groups.len > 0 {
					groups.last().ar << pat
				} else if b.pattern.elem is rosie.NonePattern {
					b.pattern = pat
				} else {
					tmp := b.pattern
					b.pattern = rosie.Pattern{ elem: rosie.GroupPattern{ word_boundary: true, ar: [tmp, pat] }}
					groups << b.pattern.is_group()?
				}
			}
			ASTQuantifier {
				if groups.len > 0 {
					// TODO Don't understand why these are not the same
					//mut last := groups.last().ar.last()
					//eprintln("last: $last")
					//last.min = elem.low
					//last.max = elem.high
					groups.last().ar.last().min = elem.low
					groups.last().ar.last().max = elem.high
				} else {
					b.pattern.min = elem.low
					b.pattern.max = elem.high
				}
			}
			ASTOpenBrace {
				pat := rosie.Pattern { elem: rosie.GroupPattern{ word_boundary: false }, predicate: predicate }
				if groups.len > 0 {
					groups.last().ar << pat
					groups << groups.last().ar.last().is_group()?
				} else if b.pattern.elem is rosie.NonePattern {
					b.pattern = pat
					groups << b.pattern.is_group()?
				} else {
					tmp := b.pattern
					b.pattern = rosie.Pattern{ elem: rosie.GroupPattern{ word_boundary: true, ar: [tmp, pat] }}
					groups << b.pattern.is_group()?
					groups << groups.last().ar.last().is_group()?
				}
			}
			ASTOpenBracket {
				pat := rosie.Pattern { elem: rosie.DisjunctionPattern{ negative: elem.complement }, predicate: predicate }
				if groups.len > 0 {
					groups.last().ar << pat
					groups << groups.last().ar.last().is_group()?
				} else if b.pattern.elem is rosie.NonePattern {
					b.pattern = pat
					groups << b.pattern.is_group()?
				} else {
					tmp := b.pattern
					b.pattern = rosie.Pattern{ elem: rosie.GroupPattern{ word_boundary: true, ar: [tmp, pat] }}
					groups << b.pattern.is_group()?
					groups << groups.last().ar.last().is_group()?
				}
			}
			ASTOpenParenthesis {
				pat := rosie.Pattern { elem: rosie.GroupPattern{ word_boundary: true }, predicate: predicate }
				if groups.len > 0 {
					groups.last().ar << pat
					groups << groups.last().ar.last().is_group()?
				} else if b.pattern.elem is rosie.NonePattern {
					b.pattern = pat
					groups << b.pattern.is_group()?
				} else {
					tmp := b.pattern
					b.pattern = rosie.Pattern{ elem: rosie.GroupPattern{ word_boundary: true, ar: [tmp, pat] }}
					groups << b.pattern.is_group()?
					groups << groups.last().ar.last().is_group()?
				}
			}
			ASTCloseBrace, ASTCloseBracket, ASTCloseParenthesis {
				groups.pop()
			}
			ASTOperator {
				if groups.len > 0 {
					groups.last().ar.last().operator = p.determine_operator(elem.op)
				} else {
					b.pattern.operator = p.determine_operator(elem.op)
				}
			}
			ASTLiteral {
				pat := rosie.Pattern { elem: rosie.LiteralPattern{ text: elem.str }, predicate: predicate }
				if groups.len > 0 {
					groups.last().ar << pat
				} else if b.pattern.elem is rosie.NonePattern {
					b.pattern = pat
				} else {
					tmp := b.pattern
					b.pattern = rosie.Pattern{ elem: rosie.GroupPattern{ word_boundary: true, ar: [tmp, pat] }}
					groups << b.pattern.is_group()?
				}
			}
			ASTCharset {
				pat := rosie.Pattern { elem: rosie.CharsetPattern{ cs: elem.cs }, predicate: predicate }
				if groups.len > 0 {
					groups.last().ar << pat
				} else if b.pattern.elem is rosie.NonePattern {
					b.pattern = pat
				} else {
					tmp := b.pattern
					b.pattern = rosie.Pattern{ elem: rosie.GroupPattern{ word_boundary: true, ar: [tmp, pat] }}
					groups << b.pattern.is_group()?
				}
			}
			ASTPredicate {
				predicate = p.determine_predicate(elem.str, rosie.PredicateType.na)?
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

				if groups.len > 0 {
					groups.last().ar << pat
					groups << (pat.elem as rosie.MacroPattern).pat.is_group()?
				} else if b.pattern.elem is rosie.NonePattern {
					b.pattern = pat
					groups << (pat.elem as rosie.MacroPattern).pat.is_group()?
				} else {
					tmp := b.pattern
					b.pattern = rosie.Pattern{ elem: rosie.GroupPattern{ word_boundary: true, ar: [tmp, pat] }}
					groups << b.pattern.is_group()?
					groups << (pat.elem as rosie.MacroPattern).pat.is_group()?
				}
			}
			ASTMacroEnd {
				groups.pop()
			}
			ASTImport {
				p.add_import_placeholder(elem.alias, elem.path)?
			}
		}
	}
	//p.package_cache.print_stats()
}

fn (p Parser) determine_operator(ch byte) rosie.OperatorType {
	return match ch {
		`/` { rosie.OperatorType.choice }
		`&` { rosie.OperatorType.conjunction }
		else { rosie.OperatorType.sequence }
	}
}

fn (p Parser) determine_predicate(str string, pred rosie.PredicateType) ? rosie.PredicateType {
	mut tok := pred

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

fn unescape(str string, unescape_all bool) ?string {
	rtn := ystrconv.interpolate_double_quoted_string(str, "")?
	//eprintln("str='$str', rtn='$rtn'")
	return rtn
}
