// ----------------------------------------------------------------------------
// Contains the actual parser
// ----------------------------------------------------------------------------

// 'grammar' are responsible for quite some special logic. I think they could
// be simplified if they were more like packages:
// 1) with (package) name, e.g. 'grammar myname'
// 2) re-use 'pub' to mark them as accessible from outside
// See https://gitlab.com/rosie-pattern-language/rosie/-/issues/120

module parser

import os
import math
import rosie

struct Parser {
pub:
	file string
	debug int
	import_path []string

pub mut:
	package_cache &PackageCache
	package string		// The current variable context
	grammar string		// Set if anywhere between 'grammar' .. 'end'

	parents []Pattern
	tokenizer Tokenizer
	last_token Token		// temp variable
	recursions []string		// Detect recursions
}

pub fn init_libpath() ? []string {
	rosie := rosie.init_rosie()?
	return rosie.libpath
}

pub struct ParserOptions {
	package string = "main"
	fpath string
	data string
	debug int
	package_cache &PackageCache = &PackageCache{}
}

pub fn new_parser(args ParserOptions) ?Parser {
	mut content := args.data
	if args.data.len == 0 && args.fpath.len > 0 {
		content = os.read_file(args.fpath)?
	}

	tokenizer := new_tokenizer(content, args.debug)?

	mut parser := Parser {
		file: args.fpath,
		tokenizer: tokenizer,
		debug: args.debug,
		package_cache: args.package_cache,
		package: args.package,
		import_path: init_libpath()?
	}

	parser.package_cache.add_package(name: args.package, fpath: args.fpath)?

	// Add builtin package, if not already present
	parser.package_cache.add_builtin()

	// Parse "rpl ..", "package .." and "import .." statements
 	parser.read_header()?

	return parser
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

fn (mut parser Parser) parse_predicate() PredicateType {
	mut rtn := PredicateType.na

	for !parser.is_eof() {
		rtn = parser.update_predicate(rtn, parser.last_token) or { break }
		parser.next_token() or { break }
	}
	return rtn
}

fn (mut parser Parser) update_predicate(pred PredicateType, tok Token) ? PredicateType {
	match tok {
		.not {
			return match pred {
				.na { PredicateType.negative_look_ahead }
				.look_ahead { PredicateType.negative_look_ahead }
				.look_behind { PredicateType.negative_look_ahead }		// See rosie doc
				.negative_look_ahead { PredicateType.look_ahead }
				.negative_look_behind { PredicateType.negative_look_ahead }
			}
		}
		.greater {
			return match pred {
				.na { PredicateType.look_ahead }
				.look_ahead { PredicateType.look_ahead }
				.look_behind { PredicateType.look_ahead }
				.negative_look_ahead { PredicateType.negative_look_ahead }
				.negative_look_behind { PredicateType.look_ahead }
			}
		}
		.smaller {
			return match pred {
				.na { PredicateType.look_behind }
				.look_ahead { PredicateType.look_behind }
				.look_behind { PredicateType.look_behind }
				.negative_look_ahead { PredicateType.negative_look_behind }
				.negative_look_behind { PredicateType.negative_look_behind }
			}
		}
		else {
			return none
		}
	}
}

fn (mut parser Parser) parse_multiplier(mut pat Pattern) ? {
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

fn (mut parser Parser) parse_operand(len int, pat Pattern) ? Pattern {
	if parser.debug > 98 {
		eprintln(">> ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}, parents=$parser.parents.len")
		defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}, parents=$parser.parents.len") }
	}

	if parser.last_token == .choice {
		parser.next_token()?
		elem := parser.parents.last().elem
		if elem is GroupPattern {
			parser.parents << Pattern{ elem: DisjunctionPattern{ negative: false } }
		}
	} else if parser.last_token == .ampersand {	// TODO The implementation is not correct. a & b is equivalent to {>a b}
		parser.next_token()?
		elem := parser.parents.last().elem
		if elem is DisjunctionPattern {
			parser.parents << Pattern{ elem: GroupPattern{ word_boundary: false } }
		}
	} else {  // No operator
		if parser.parents.len > len {
			elem := parser.parents.last().elem
			if elem is DisjunctionPattern {
				parser.parents.last().is_group()?.ar << pat
				return parser.parents.pop()
			}
		}
	}

	return pat
}

// parse_single_expression This is to parse a simple expression, such as
// "aa", !"bb" !<"cc", "dd"*, [:digit:]+ etc.
fn (mut parser Parser) parse_single_expression(level int) ? Pattern {
	if parser.debug > 98 {
		eprintln(">> ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}, parents=$parser.parents.len")
		defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}, parents=$parser.parents.len") }
	}

	mut pat := Pattern{ predicate: parser.parse_predicate() }
	mut t := &parser.tokenizer

	match parser.last_token()? {
		.quoted_text {
			pat.elem = LiteralPattern{ text: t.get_quoted_text() }
			parser.next_token() or {}
		}
		.text {
			text := t.get_text()
			if text == "." {
				pat.elem = NamePattern{ name: "." }
			} else if text == "$" {
				pat.elem = EofPattern{ eof: true }
			} else if text == "^" {
				pat.elem = EofPattern{ eof: false }
			} else {
				pat.elem = NamePattern{ name: text }
			}
			parser.next_token() or {}
		}
		.charset {
			cs := parser.parse_charset_token()?
			pat.elem = CharsetPattern{ cs: cs }
		}
		.open_bracket {
			parser.next_token()?
			pat.elem = DisjunctionPattern{ negative: false }
			parser.parents << pat
			parser.parse_compound_expression(level + 1)?	// TODO level == parents.len ?!?!
			parser.parents.pop()
			parser.next_token() or {}
		}
		.open_parentheses {
			parser.next_token()?
			pat.elem = GroupPattern{ word_boundary: false }
			parser.parents << pat
			parser.parse_compound_expression(level + 1)?
			pat = parser.parents.pop()
			parser.next_token() or {}
			parser.parse_multiplier(mut pat)?
			pat = Pattern{ elem: MacroPattern{ name: "tok", pat: pat } }
			return pat
		}
		.open_brace {
			parser.next_token()?
			pat.elem = GroupPattern{ word_boundary: false }
			parser.parents << pat
			parser.parse_compound_expression(level + 1)?
			parser.parents.pop()
			parser.next_token() or {}
		}
		.tilde {
			pat.elem = NamePattern{ name: "~" }
			parser.next_token() or {}
		}
		.macro {
			text := t.get_text()
			name := text[.. text.len - 1]
			parser.next_token() or {}
			parser.parents << Pattern{ elem: GroupPattern{ word_boundary: false } }
			p := parser.parse_single_expression(level + 1)?
			parser.parents.pop()
			pat.elem = MacroPattern{ name: name, pat: p }
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
		if mut pat.elem is DisjunctionPattern {
			pat.elem.merge_charsets()
		}

		parser.parents.last().is_group()?.ar << pat
	}

	mut elem := parser.parents[len - 1].elem
	if mut elem is DisjunctionPattern {
		elem.merge_charsets()
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

pub fn (mut parser Parser) parse() ? {
	parser.parse_inner() or {
		lno, col := parser.tokenizer.scanner.line_no()
		//eprintln("lno: $lno, $col")
		line_no := if lno - 3 < 0 { 0 } else { lno - 3 }
		data := parser.tokenizer.scanner.text.split_into_lines()
		mut str := "\nERROR: $parser.file:$lno:$col: warning: $err.msg\n"
		for i in line_no .. lno {
			str += "${i + 1:5d} | ${data[i]}\n"
		}
		return error(str)
	}
}
