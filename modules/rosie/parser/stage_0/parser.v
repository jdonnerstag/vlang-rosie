// ----------------------------------------------------------------------------
// Contains the actual parser
// ----------------------------------------------------------------------------

// 'grammar' are responsible for quite some special logic. I think they could
// be simplified if they were more like packages:
// 1) with (package) name, e.g. 'grammar myname'
// 2) re-use 'pub' to mark them as accessible from outside
// See https://gitlab.com/rosie-pattern-language/rosie/-/issues/120

module stage_0

import os
import math
import rosie

// Parser
struct Parser {
pub:
	debug int
	import_path []string

pub mut:
	file string				// User defined patterns are from a file (vs. command line)
	package_cache &rosie.PackageCache
	main &rosie.Package 	// The main package
	current &rosie.Package	// The current package context: either "main" or a grammar package

	parents []rosie.Pattern	// The parents of the current pattern during the parsing process
	tokenizer Tokenizer
	last_token Token		// temp variable
	recursions []string		// Detect recursions
	imports []rosie.ImportStmt	// file path of the imports
}

pub fn init_libpath() ? []string {
	rosie := rosie.init_rosie()?
	return rosie.libpath
}

[params]
pub struct CreateParserOptions {
	debug int
	package_cache &rosie.PackageCache = rosie.new_package_cache()
	libpath []string = init_libpath()?
}

pub fn new_parser(args CreateParserOptions) ?Parser {
	// TODO IMHO this is a V security bug. I can assign an immutable variable (ptr in this case)
	//   to a mutable variable, and I'm now able to modify the variable. May be that is
	//   not a big thing when variables are passed by value. But whenever pointers are
	//   used, either implicitly or explicitly, I can now modify immutable content !!!
	main := rosie.new_package(name: "main", fpath: "main", parent: args.package_cache.builtin())

	mut parser := Parser {
		tokenizer: new_tokenizer(args.debug)
		debug: args.debug
		main: main
		current: main
		import_path: args.libpath
		package_cache: args.package_cache
	}

	return parser
}

pub fn (mut parser Parser) parse(args rosie.ParserOptions) ? {
	// Just in case the parser is being re-used multiple times.
	parser.parents.clear()
	parser.recursions.clear()

	if args.package.len > 0 {
		parser.main.name = args.package
	}

	if args.file.len > 0 {
		parser.file = args.file
		parser.main.fpath = args.file
		parser.main.name = args.file.all_before_last(".").all_after_last("/").all_after_last("\\")
	}

	// Read the file content, if a file name has been provided
	mut data := args.data
	if data.len == 0 && args.file.len > 0 {
		data = os.read_file(args.file)?
	}

	if data.len == 0 {
		return error("RPL pattern missing. Either use 'data' or 'file' parameter.")
	}

	// Initialize the tokenizer with the user provided rpl
	parser.tokenizer.init(data)?

	// Parse "rpl ..", "package .." and "import .." statements
	// Note: The 'package' statement will reset parser.package
	parser.read_header()?

	// Tokenize and parse the RPL, create bindings and add them to the package
	parser.current = parser.main
	parser.parse_inner() or {
		lno, col := parser.tokenizer.scanner.line_no()
		//eprintln("lno: $lno, $col")
		line_no := if lno - 3 < 0 { 0 } else { lno - 3 }
		lines := parser.tokenizer.scanner.text.split_into_lines()
		file := if args.file.len > 0 { args.file } else { "<no file>" }
		mut str := "\nERROR: $file:$lno:$col: warning: $err.msg\n"
		for i in line_no .. lno {
			str += "${i + 1:5d} | ${lines[i]}\n"
		}
		return error(str)
	}

	if args.ignore_imports == false {
		// This can only work, if the import files have a compliant RPL version.
		// Else, let MasterParser do the import.
		parser.import_packages()?
	}
}

pub fn (mut parser Parser) next_token() ?Token {
	mut tok := parser.tokenizer.next_token()?
	for tok == .comment || (tok == .text && parser.tokenizer.peek_text().len == 0) {
		tok = parser.tokenizer.next_token()?
	}
	parser.last_token = tok
	return tok
}

//[inline]
fn (parser Parser) is_eof() bool {
	s := &parser.tokenizer.scanner
	return s.last_pos >= s.text.len
}

//[inline]
fn (parser Parser) last_token() ?Token {
	if parser.is_eof() { return none }
	return parser.last_token
}

fn (mut parser Parser) peek_text(text string) bool {
	if !parser.is_eof() && parser.last_token == .text && parser.tokenizer.peek_text() == text {
		if _ := parser.next_token() {
			return true
		}
	}
	return false
}

fn (mut parser Parser) get_text() string {
	str := parser.tokenizer.get_text()
	parser.next_token() or {}
	return str
}

fn (parser Parser) is_keyword() bool {
	return parser.last_token == .text && parser.tokenizer.peek_text() in ["alias", "local", "grammar", "in", "end", "let", "func", "builtin"]
}

fn (mut parser Parser) is_end_of_pattern() bool {
	return
		parser.is_eof() ||
		parser.last_token in [.close_brace, .close_parentheses, .close_bracket, .semicolon] ||
		parser.is_keyword() ||
		parser.is_assignment()
}

fn (mut parser Parser) is_assignment() bool {
	if parser.last_token in [.text, .tilde] {
		mut t := &parser.tokenizer.scanner
		last_pos := t.last_pos
		pos := t.pos
		if tok := parser.tokenizer.next_token() {
			if tok == .equal {
				t.last_pos = last_pos
				t.pos = pos
				return true
			}
		}
		t.last_pos = last_pos
		t.pos = pos
	}
	return false
}

fn (mut parser Parser) debug_input() string {
	s := &parser.tokenizer.scanner
	p1 := s.last_pos
	p2 := int(math.min(s.text.len, p1 + 40))
	mut str := parser.tokenizer.scanner.text[p1 .. p2]
	str = str.replace("\r\n", "\\n")
	return str
}

fn (mut parser Parser) parse_predicate() rosie.PredicateType {
	mut rtn := rosie.PredicateType.na

	for !parser.is_eof() {
		rtn = parser.update_predicate(rtn, parser.last_token) or { break }
		parser.next_token() or { break }
	}
	return rtn
}

fn (mut parser Parser) update_predicate(pred rosie.PredicateType, tok Token) ? rosie.PredicateType {
	match tok {
		.not {
			return match pred {
				.na { rosie.PredicateType.negative_look_ahead }
				.look_ahead { rosie.PredicateType.negative_look_ahead }
				.look_behind { rosie.PredicateType.negative_look_ahead }		// See rosie doc
				.negative_look_ahead { rosie.PredicateType.look_ahead }
				.negative_look_behind { rosie.PredicateType.negative_look_ahead }
			}
		}
		.greater {
			return match pred {
				.na { rosie.PredicateType.look_ahead }
				.look_ahead { rosie.PredicateType.look_ahead }
				.look_behind { rosie.PredicateType.look_ahead }
				.negative_look_ahead { rosie.PredicateType.negative_look_ahead }
				.negative_look_behind { rosie.PredicateType.look_ahead }
			}
		}
		.smaller {
			return match pred {
				.na { rosie.PredicateType.look_behind }
				.look_ahead { rosie.PredicateType.look_behind }
				.look_behind { rosie.PredicateType.look_behind }
				.negative_look_ahead { rosie.PredicateType.negative_look_behind }
				.negative_look_behind { rosie.PredicateType.negative_look_behind }
			}
		}
		else {
			return none
		}
	}
}

fn (mut parser Parser) parse_multiplier(mut pat rosie.Pattern) ? {
	if parser.debug > 100 {
		eprintln(">> ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}")
		defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}") }
	}

	if !parser.is_eof() {
		match parser.last_token {
			.star {
				pat.min = 0
				pat.max = -1
				parser.next_token() or {}
			}
			.plus {
				pat.min = 1
				pat.max = -1
				parser.next_token() or {}
			}
			.question_mark {
				pat.min = 0
				pat.max = 1
				parser.next_token() or {}
			}
			.open_brace {
				s := &parser.tokenizer.scanner
				if s.pos > 1 && s.text[s.pos - 2].is_space() == false {
					pat.min, pat.max = parser.parse_curly_multiplier()?
				}
			} else {}
		}
	}
}

fn (mut parser Parser) parse_curly_multiplier() ?(int, int) {
	if parser.debug > 100 {
		eprintln(">> ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}")
		defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}") }
	}

	mut t := &parser.tokenizer
	mut min := 1
	mut max := 1

	mut tok := parser.next_token()?	// skip '{'
	if tok == .comma {
		min = 0
	} else if tok == .text {
		min = t.get_text().int()
		tok = parser.next_token()?
	} else {
		return error("Pattern multiplier: expected either ',' or a digit to follow '{'")
	}

	if tok == .close_brace {
		max = min
	} else if tok == .comma {
		tok = parser.next_token()?
		if tok == .close_brace {
			max = -1
		} else if tok == .text {
			max = t.get_text().int()
			tok = parser.next_token()?
		} else {
			return error("Pattern multiplier: expected either a digit or '}'")
		}
	}

	if tok != .close_brace {
		return error("Expected '}' to close multiplier: '$tok'")
	}
	parser.next_token() or {}
	return min, max
}

fn (mut parser Parser) parse_operand(len int, pat rosie.Pattern) ? rosie.Pattern {
	if parser.debug > 98 {
		eprintln(">> ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}, parents=$parser.parents.len")
		defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}, parents=$parser.parents.len") }
	}

	if parser.last_token == .choice {
		parser.next_token()?
		elem := parser.parents.last().elem
		if elem is rosie.GroupPattern {
			parser.parents << rosie.Pattern{ elem: rosie.DisjunctionPattern{ negative: false } }
		}
	} else if parser.last_token == .ampersand {	// TODO The implementation is not correct. a & b is equivalent to {>a b}
		parser.next_token()?
		elem := parser.parents.last().elem
		if elem is rosie.DisjunctionPattern {
			parser.parents << rosie.Pattern{ elem: rosie.GroupPattern{ word_boundary: false } }
		}
	} else {  // No operator
		if parser.parents.len > len {
			elem := parser.parents.last().elem
			if elem is rosie.DisjunctionPattern {
				parser.parents.last().is_group()?.ar << pat
				return parser.parents.pop()
			}
		}
	}

	return pat
}

// parse_single_expression This is to parse a simple expression, such as
// "aa", !"bb" !<"cc", "dd"*, [:digit:]+ etc.
fn (mut parser Parser) parse_single_expression(level int) ? rosie.Pattern {
	if parser.debug > 98 {
		eprintln(">> ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}, parents=$parser.parents.len")
		defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}, parents=$parser.parents.len") }
	}

	mut pat := rosie.Pattern{ predicate: parser.parse_predicate() }
	mut t := &parser.tokenizer

	match parser.last_token()? {
		.quoted_text {
			pat.elem = rosie.LiteralPattern{ text: t.get_quoted_text() }
			parser.next_token() or {}
		}
		.text {
			text := t.get_text()
			if text == "." {
				pat.elem = rosie.NamePattern{ name: "." }
			} else if text == "$" {
				pat.elem = rosie.EofPattern{ eof: true }
			} else if text == "^" {
				pat.elem = rosie.EofPattern{ eof: false }
			} else {
				pat.elem = rosie.NamePattern{ name: text }
			}
			parser.next_token() or {}
		}
		.charset {
			cs := parser.parse_charset_token()?
			pat.elem = rosie.CharsetPattern{ cs: cs }
		}
		.open_bracket {
			parser.next_token()?
			pat.elem = rosie.DisjunctionPattern{ negative: false }
			parser.parents << pat
			parser.parse_compound_expression(level + 1)?	// TODO level == parents.len ?!?!
			parser.parents.pop()
			parser.next_token() or {}
		}
		.open_parentheses {
			parser.next_token()?
			pat.elem = rosie.GroupPattern{ word_boundary: true }
			parser.parents << pat
			parser.parse_compound_expression(level + 1)?
			parser.parents.pop()
			parser.next_token() or {}
		}
		.open_brace {
			parser.next_token()?
			pat.elem = rosie.GroupPattern{ word_boundary: false }
			parser.parents << pat
			parser.parse_compound_expression(level + 1)?
			parser.parents.pop()
			parser.next_token() or {}
		}
		.tilde {
			pat.elem = rosie.NamePattern{ name: "~" }
			parser.next_token() or {}
		}
		.macro {
			text := t.get_text()
			name := text[.. text.len - 1]
			parser.next_token() or {}
			parser.parents << rosie.Pattern{ elem: rosie.GroupPattern{ word_boundary: false } }
			p := parser.parse_single_expression(level + 1)?
			parser.parents.pop()
			pat.elem = rosie.MacroPattern{ name: name, pat: p }
		}
		else {
			return error("Unexpected tag found: .$parser.last_token")
		}
	}

	parser.parse_multiplier(mut pat)?
	return pat
}

fn (mut parser Parser) parse_compound_expression(level int) ? {
	if parser.debug > 90 {
		dummy := parser.debug_input()
		eprintln(">> ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}, parents=$parser.parents.len, level=$level, text='${dummy}'")
		defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}, parents=$parser.parents.len, level=$level, text='${dummy}'") }
	}

	len := parser.parents.len
	for !parser.is_end_of_pattern()	{
		mut pat := parser.parse_single_expression(level)?

		if !parser.is_eof() { pat = parser.parse_operand(len, pat)? }

		parser.parents.last().is_group()?.ar << pat
	}

	for len < parser.parents.len {
		mut pat := parser.parents.pop()
		if mut pat.elem is rosie.DisjunctionPattern {
			merge_charsets(mut pat.elem)
		}

		parser.parents.last().is_group()?.ar << pat
	}

	mut elem := parser.parents[len - 1].elem
	if mut elem is rosie.DisjunctionPattern {
		merge_charsets(mut elem)
	}
}

fn (mut parser Parser) parse_inner() ? {
	for !parser.is_eof() {
		if parser.last_token == .semicolon {
			parser.next_token()?
		} else if parser.peek_text("grammar") {
			parser.parse_grammar()?
		} else {
			parser.parse_binding()?
		}
	}
}
