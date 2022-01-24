module rpl_3_0

import os
import rosie
import rosie.parser.rpl_1_3 as parser
import rosie.expander
import rosie.compiler.v2 as compiler
import rosie.runtimes.v2 as rt

struct ASTModule { }
struct ASTPackageDecl { name string }
struct ASTIdentifier { name string }
struct ASTMacro { name string }
struct ASTMacroEnd { }
struct ASTOpenParenthesis{ }	// ( )
struct ASTCloseParenthesis { }
struct ASTOperator { op byte }
struct ASTLiteral { str string }
struct ASTPredicate { str string }
struct ASTCharset { cs rosie.Charset }
struct ASTMain { }

struct ASTBinding {
	name string
	alias bool
	builtin bool
	recursive bool
	func bool
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
	ASTOpenParenthesis |
	ASTCloseParenthesis |
	ASTOperator |
	ASTLiteral |
	ASTCharset |
	ASTPredicate |
	ASTMacro |
	ASTMacroEnd |
	ASTImport |
	ASTMain


enum SymbolEnum {
    star_idx
	module_idx
	expression_idx
	language_decl_idx
	major_idx
	minor_idx
	package_decl_idx
	package_name_idx
	statement_idx
	importpath_idx
	identifier_idx
	quantifier_idx
	low_idx
	high_idx
	open_parentheses_idx
	close_parentheses_idx
	literal_idx
	operator_idx
	charlist_idx
	syntax_error_idx
	predicate_idx
	named_charset_idx
	complement_idx
	simple_charset_idx
	charset_idx
	modifier_idx
	macro_idx
	macro_end_idx
	term_idx
	main_idx
	attributes_idx
}

fn init_symbol_table(mut symbols rosie.Symbols) {
	assert symbols.symbols.len == 0		// array must be empty

	// VERY IMPORTANT: The sequence must exactly match the SymbolEnum from above !!!

	symbols.symbols << "main.*"
	symbols.symbols << "rpl_3_0.rpl_module"
	symbols.symbols << "rpl_3_0.rpl_expression"
	symbols.symbols << "rpl_3_0.language_decl"
	symbols.symbols << "rpl_3_0.major"
	symbols.symbols << "rpl_3_0.minor"
	symbols.symbols << "rpl_3_0.package_decl"
	symbols.symbols << "rpl_3_0.packagename"
	symbols.symbols << "rpl_3_0.statement"
	symbols.symbols << "rpl_3_0.importpath"
	symbols.symbols << "rpl_3_0.identifier"
	symbols.symbols << "rpl_3_0.quantifier"
	symbols.symbols << "rpl_3_0.low"
	symbols.symbols << "rpl_3_0.high"
	symbols.symbols << "rpl_3_0.open_parentheses"
	symbols.symbols << "rpl_3_0.close_parentheses"
	symbols.symbols << "rpl_3_0.literal"
	symbols.symbols << "rpl_3_0.operator"
	symbols.symbols << "rpl_3_0.charlist"
	symbols.symbols << "rpl_3_0.syntax_error"
	symbols.symbols << "rpl_3_0.predicate"
	symbols.symbols << "rpl_3_0.named_charset"
	symbols.symbols << "rpl_3_0.complement"
	symbols.symbols << "rpl_3_0.simple_charset"
	symbols.symbols << "rpl_3_0.charset"
	symbols.symbols << "rpl_3_0.modifier"
	symbols.symbols << "grammar-0.macro"
	symbols.symbols << "grammar-0.macro_end"
	symbols.symbols << "grammar-0.term"
	symbols.symbols << "rpl_3_0.main"
	symbols.symbols << "rpl_3_0.attributes"
}

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
	main &rosie.Package		// The package that will receive the bindings being parsed.
	imports []rosie.ImportStmt		// file path of the imports

mut:
	current &rosie.Package	// Set if parser is anywhere between 'grammar' and 'end'
	cli_mode bool			// True if pattern is an expression (cli), else a module (file)
	package_cache &rosie.PackageCache	// Packages already imported
	m rt.Match				// The RPL runtime to parse the user provided pattern (eat your own dog food)
}

const (
	rpl_3_0_fpath = "./rpl/rosie/rpl_3_0.rpl"
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
	rplx := os.file_last_mod_unix(rplx_fname) - 5 // secs

	if rpl <= rplx {
		return true
	}

	eprintln("Info: The *.rplx file is outdated. $rpl_fname")
	return false
}

fn load_rplx(fname string) ? &rt.Rplx {

	if is_rpl_file_newer(fname) == false {

		// We are using the core_0 parser to parse the rpl-1.3 RPL pattern, which
		// we then use to parse the user's rpl pattern.
eprintln("Parse file: $fname")
		rpl_data := os.read_file(fname)?

		mut p := parser.new_parser(debug: 0)?
		p.parse(data: rpl_data)?

		mut c := compiler.new_compiler(p.main, unit_test: true, debug: p.debug)

		mut e := expander.new_expander(main: p.main, debug: p.debug, unit_test: false)
		e.expand(rpl_module) or {
			return error("Compiler failure in expand(): $err.msg")
		}
		c.compile(rpl_module)?

		e.expand(rpl_expression)?
		c.compile(rpl_expression)?

		return c.rplx
	}

	// We do not know, whether on the client computer the user is allowed to create or replace a
	// file in the respective directory. It can be done manually like so:
	// CMD: rosie_cli.exe compile .\rpl\rosie\rpl_1_3_jdo.rpl rpl_module rpl_expression
	return rt.rplx_load(fname + "x")
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

	rplx := load_rplx(rpl_3_0_fpath)?

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
	main := rosie.new_package(name: "main", fpath: "main")

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
	ast := p.parse_into_ast(data, entrypoint)?

	// Read the ASTElem stream and create bindings and pattern from it
	p.construct_bindings(ast)?

	//p.expand_word_boundary(mut p.main)?
	//p.expand_word_boundary(mut p.package_cache.builtin())?

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

fn (mut p Parser) validate_language_decl() ? {
	//p.m.print_capture_level(0, any: true)
	if cap := p.m.get_halt_capture() {
		if cap.idx == int(SymbolEnum.language_decl_idx) {
			major_idx := p.m.child_capture(p.m.halt_capture_idx, p.m.halt_capture_idx, int(SymbolEnum.major_idx))?
			minor_idx := p.m.child_capture(p.m.halt_capture_idx, major_idx, int(SymbolEnum.minor_idx))?
			major := p.m.get_capture_input(&p.m.captures[major_idx])
			minor := p.m.get_capture_input(&p.m.captures[minor_idx])
			p.main.language = "${major}.${minor}"

			if major != "3" {
				return error_with_code("The selected RPL 3.x parser does not support RPL ${major}.${minor}", rosie.err_rpl_version_not_supported)
			}
		}
	}
}

pub fn (mut p Parser) find_culprit() string {
	for cap in p.m.captures {
		if cap.level == 1 && cap.matched == true {
			return p.m.get_capture_input(cap)
		}
	}

	return p.m.input
}

pub fn (mut p Parser) parse_into_ast(rpl string, entrypoint string) ? []ASTElem {
	p.m = rt.new_match(rplx: p.rplx, entrypoint: entrypoint, debug: p.debug)
	mut rtn := p.m.vm_match(rpl)?

	if p.m.halted() {	// See halt:tok:{"rpl" version_spec ";"?}
		if rtn {
			p.validate_language_decl()?
		}

		rtn = p.m.vm_continue(false)?
	}

	if rtn == false {
		p.m.print_capture_level(0, any: true)
		mut str := p.find_culprit()
		if str.len > 25 { str = str[0 .. 25] + ".." }
		str = str.replace("\n", "\\n").replace("\r", "\\r")
		return error("RPL parser error: Input is not valid RPL 3.x: '$str'")
	}

	mut ar := []ASTElem{ cap: p.m.captures.len / 8 }

	// See https://github.com/vlang/v/issues/12411 for a V-bug on iterators
	mut iter := p.m.captures.my_filter(pos: 0, level: 0, any: false)
	for {
		cap := iter.next() or { break }

		match SymbolEnum(cap.idx) {
			.module_idx {
				ar << ASTModule{}
			}
			.expression_idx {
				// skip
			}
			.term_idx {
				// skip
			}
			.main_idx {
				ar << ASTMain{}
			}
			.language_decl_idx {
				major_cap := iter.next() or { break }
				minor_cap := iter.next() or { break }
				if SymbolEnum(major_cap.idx) != .major_idx {
					p.m.print_capture_level(0, last: iter.last())
					return error("RPL parser: expected to find 'rpl_3_0.major' at ${iter.last()}, but found ${p.m.capture_str(cap)}")
				}
				if SymbolEnum(minor_cap.idx) != .minor_idx {
					p.m.print_capture_level(0, last: iter.last())
					return error("RPL parser: expected to find 'rpl_3_0.minor' at ${iter.last()}, but found ${p.m.capture_str(cap)}")
				}
				major := p.m.get_capture_input(major_cap).int()
				minor := p.m.get_capture_input(minor_cap).int()
				p.main.language = "${major}.${minor}"

				// TODO We first finish parsing, and then we analyse the captures. That is, we recognized the wrong version only late and we are wasting CPU cycles.
				if major != 3 {
					return error_with_code(
						"RPL error: the selected parser does not support RPL ${major}.${minor}",
						rosie.err_rpl_version_not_supported
					)
				}

				ar << ASTLanguageDecl{ major: major, minor: minor }
			}
			.package_decl_idx {
				name_cap := iter.next() or { break }
				if SymbolEnum(name_cap.idx) != .package_name_idx {
					p.m.print_capture_level(0, last: iter.last())
					return error("RPL parser: expected to find 'rpl_3_0.packagename' at ${iter.last()}, but found ${p.m.capture_str(cap)}")
				}
				name := p.m.get_capture_input(name_cap)
				ar << ASTPackageDecl{ name: name }
			}
			.statement_idx {
				if p.m.get_capture_input(cap).starts_with(";") == false {
					mut alias_ := false
					mut recursive_ := false
					mut builtin_ := false
					mut func_ := false

					mut next_cap := iter.peek_next() or { break }
					if SymbolEnum(next_cap.idx) == .modifier_idx {
						modifier := p.m.get_capture_input(next_cap)
						if modifier == "alias" {
							iter.next() or { break }
							alias_ = true
						} else {
							// will never happen
						}
					}

					identifier_cap := iter.next() or { break }
					if SymbolEnum(identifier_cap.idx) != .identifier_idx {
						p.m.print_capture_level(0, last: iter.last())
						return error("RPL parser: expected to find 'rpl_3_0.identifier' at ${iter.last()}, but found ${p.m.capture_str(cap)}")
					}
					name := p.m.get_capture_input(identifier_cap)

					for {
						next_cap = iter.peek_next() or { break }
						if SymbolEnum(next_cap.idx) != .attributes_idx { break }

						attribute := p.m.get_capture_input(next_cap)
						match attribute {
							"[recursive]" { recursive_ = true }
							"[builtin]" { builtin_ = true }
							"[func]" { func_ = true }
							else { /* will never happen */ }
						}
						iter.next() or { break }
					}
					ar << ASTBinding{ name: name, alias: alias_, builtin: builtin_, recursive: recursive_, func: func_ }
				}
			}
			.charset_idx {
				mut next_cap := iter.next() or { break }
				mut complement := false
				if SymbolEnum(next_cap.idx) == .complement_idx {
					complement = true
					next_cap = iter.next() or { break }
				}

				mut cs := rosie.new_charset()
				for {
					if SymbolEnum(next_cap.idx) == .simple_charset_idx {
						cs2 := p.parse_charset(mut iter) or { break }
						cs.merge_or_modify(cs2)
					} else if SymbolEnum(next_cap.idx) == .identifier_idx {
						name := p.m.get_capture_input(next_cap)
						b := p.binding(name)?
						if b.pattern.elem is rosie.CharsetPattern {
							cs.merge_or_modify(b.pattern.elem.cs)
							next_cap = iter.next() or { break }
						} else {
							p.m.print_capture_level(0, last: iter.last())
							return error("Only identifiers referring to charsets are allowed at ${iter.last()}: '${p.m.capture_str(cap)}'")
						}
					}

					next_cap = iter.peek_next() or { break }
					if SymbolEnum(next_cap.idx) !in [.simple_charset_idx, .identifier_idx] {
						break
					}
					next_cap = iter.next() or { break }
				}

				if complement {
					cs = cs.complement()
				}
				ar << ASTCharset{ cs: cs }
			}
			.quantifier_idx {
				mut str := p.m.get_capture_input(cap)
				if str == "*" {
					ar << ASTQuantifier{ low: 0, high: -1 }
				} else if str == "?" {
					ar << ASTQuantifier{ low: 0, high: 1 }
				} else if str == "+" {
					ar << ASTQuantifier{ low: 1, high: -1 }
				} else {
					low_cap := iter.next() or { break }
					if SymbolEnum(low_cap.idx) != .low_idx {
						p.m.print_capture_level(0, last: iter.last())
						return error("RPL parser: expected to find 'rpl_3_0.low' at ${iter.last()}, but found ${p.m.capture_str(low_cap)}")
					}
					low := p.m.get_capture_input(low_cap).int()

					mut high := low
					if high_cap := iter.peek_next() {
						if SymbolEnum(high_cap.idx) == .high_idx {
							iter.next() or { break }
							str = p.m.get_capture_input(high_cap)
							high = if str.len == 0 { -1 } else { str.int() }
						}
					}
					ar << ASTQuantifier{ low: low, high: high }
				}
			}
			.open_parentheses_idx {
				ar << ASTOpenParenthesis{}
			}
			.close_parentheses_idx {
				ar << ASTCloseParenthesis{}
			}
			.literal_idx {
				str := p.m.get_capture_input(cap)
				ar << ASTLiteral{ str: unescape(str) }
			}
			.operator_idx {
				str := p.m.get_capture_input(cap)
				ar << ASTOperator{ op: str[0] }
			}
			.identifier_idx {
				str := p.m.get_capture_input(cap)
				ar << ASTIdentifier{ name: str }
			}
			.predicate_idx {
				str := p.m.get_capture_input(cap)
				ar << ASTPredicate{ str: str }
			}
			.macro_idx {
				next_cap := iter.next() or { break }
				if SymbolEnum(next_cap.idx) != .identifier_idx {
					p.m.print_capture_level(0, any: true, last: iter.last())
					return error("RPL parser: Expected 'identifier' capture: ${p.m.capture_str(cap)}")
				}

				str := p.m.get_capture_input(next_cap)
				ar << ASTMacro{ name: str }
			}
			.macro_end_idx {
				ar << ASTMacroEnd{ }
			}
			.importpath_idx {
				mut path := p.m.get_capture_input(cap)
				mut alias := path
				if next_cap := iter.peek_next() {
					if SymbolEnum(next_cap.idx) == .literal_idx {
						path = p.m.get_capture_input(next_cap)
						iter.next() or { break }
					}
				}

				if next_cap := iter.peek_next() {
					if SymbolEnum(next_cap.idx) == .package_name_idx {
						iter.next() or { break }
						alias = p.m.get_capture_input(next_cap)
					}
				}

				ar << ASTImport{ path: path, alias: alias }
			}
			.syntax_error_idx {
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

pub fn (mut p Parser) parse_charset(mut iter rosie.CaptureFilter) ? rosie.Charset {
	mut next_cap := iter.next() or { return none }
	mut complement := false
	if SymbolEnum(next_cap.idx) == .complement_idx {
		complement = true
		next_cap = iter.next() or { return none }
	}

	mut cs := rosie.new_charset()
	if SymbolEnum(next_cap.idx) == .charlist_idx {
		str := p.m.get_capture_input(next_cap)
		cs.from_rpl(str)
	} else if SymbolEnum(next_cap.idx) == .named_charset_idx {
		str := p.m.get_capture_input(next_cap)
		cs = rosie.known_charsets[str] or {
			return error("RPL parser: invalid charset name: '$str'")
		}
	}

	if complement {
		cs = cs.complement()
	}
	return cs
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
			}
			ASTPackageDecl {
				p.main.name = elem.name
			}
			ASTMain {
				mut b := p.main.new_binding(name: "*", public: true, alias: false, recursive: false)?

				b.pattern.elem = rosie.GroupPattern{ word_boundary: false }

				groups.clear()
				groups << b.pattern.is_group()?
			}
			ASTBinding {
				mut b := &rosie.Binding(0)
				if elem.builtin == false {
					b = p.current.new_binding(name: elem.name, package: p.main.name, public: true, alias: elem.alias, recursive: false)?
				} else {
					mut pkg := p.package_cache.builtin()
					b = pkg.replace_binding(name: elem.name, package: p.main.name, public: true, alias: elem.alias, recursive: false)?
				}

				b.pattern.elem = rosie.GroupPattern{ word_boundary: true }

				groups.clear()
				groups << b.pattern.is_group()?
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
			ASTOpenParenthesis {
				groups.last().ar << rosie.Pattern { elem: rosie.GroupPattern{ word_boundary: false }, predicate: predicate }
				groups << groups.last().ar.last().is_group()?
			}
			ASTCloseParenthesis {
				groups.pop()
			}
			ASTOperator {
				groups.last().ar.last().operator = p.determine_operator(elem.op)
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
				//mut macro := &(groups.last().ar.last().elem as rosie.MacroPattern)
				//eprintln(macro)
				//p.expand_walk_word_boundary(mut macro.pat)
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

	// If a group has only 1 element, then ignore the group
	p.eliminate_one_group(mut pat)
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
