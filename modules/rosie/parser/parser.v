// ----------------------------------------------------------------------------
// Contains the actual parser
// ----------------------------------------------------------------------------

module parser

import os
import math

struct Parser {
pub:
	file string
	debug int
	import_path []string

pub mut:
	package_cache Packages
	package Package

	tokenizer Tokenizer
	last_token Token				// temp variable
}

pub fn init_libpath() []string {
	return ["./", r"C:\source_code\vlang\vlang-rosie\rpl"]	// TODO: see env{"ROSIE_LIBPATH"} and $rosie_home/rpl
}

pub struct ParserOptions {
	fpath string
	data string
	debug int
	package_cache Packages
}

pub fn new_parser(args ParserOptions) ?Parser {
	if args.fpath.len > 0 && args.data.len > 0 {
		panic("Please provide either 'fpath' or 'data' arguments, but not both")
	}

	mut content := args.data
	if args.fpath.len > 0 {
		content = os.read_file(args.fpath)?
	}

	tokenizer := new_tokenizer(content, args.debug)?

	mut parser := Parser {
		file: args.fpath,
		tokenizer: tokenizer,
		debug: args.debug,
		package_cache: args.package_cache,
		import_path: init_libpath()
	}

	// TODO Add some builtin package to the package cache
	parser.add_charset_binding("$", known_charsets["$"])

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
	return parser.last_token == .text && parser.tokenizer.peek_text() in ["alias", "local", "grammar", "in", "end", "let"]
}

fn (mut parser Parser) is_end_of_pattern() bool {
	return
		parser.is_eof() ||
		parser.last_token in [.close_brace, .close_parentheses, .semicolon] ||
		parser.is_keyword() ||
		parser.is_assignment()
}

fn (mut parser Parser) is_assignment() bool {
	if parser.last_token == .text {
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
		match parser.last_token {
			.not {
				// TODO This is not yet allowing arbitrary combinations, such !<>!<!!
				rtn = match rtn {
					.look_ahead { PredicateType.negative_look_ahead }
					.look_behind { PredicateType.negative_look_behind }
					else { PredicateType.negative_look_ahead }
				}
			}
			.greater {
				// TODO This is not yet allowing arbitrary combinations, such !<>!<!!
				rtn = .look_ahead
			}
			.smaller {
				// TODO This is not yet allowing arbitrary combinations, such !<>!<!!
				rtn = .look_behind
			}
			else {
				return rtn
			}
		}

		parser.next_token() or { break }
	}
	return rtn
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
		tok = parser.next_token()?
	} else {
		min = t.get_text().int()
		tok = parser.next_token()?
		if tok == .comma { tok = parser.next_token()? }
	}

	if tok == .close_brace {
		max = -1
	} else {
		max = t.get_text().int()
		tok = parser.next_token()?
		if tok != .close_brace {
			return error("Expected '}' to close multiplier: '$tok'")
		}
	}

	parser.next_token() or {}
	return min, max
}

fn (mut parser Parser) parse_operand(mut p Pattern) ? {
	if parser.debug > 98 {
		eprintln(">> ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}")
		defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}") }
	}

	match parser.last_token {
		.choice {
			parser.next_token()?
			p.operator = OperatorType.choice
		}
		.ampersand {
			parser.next_token()?
			p.operator = OperatorType.conjunction
		}
		.tilde {
			parser.next_token()?
			p.word_boundary = true
		}
		else {
			p.operator = OperatorType.sequence
		}
	}
}

// parse_single_expression This is to parse a simple expression, such as
// "aa", !"bb" !<"cc", "dd"*, [:digit:]+ etc.
fn (mut parser Parser) parse_single_expression(word bool, level int) ?Pattern {
	if parser.debug > 98 {
		eprintln(">> ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}")
		defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}") }
	}

	mut pat := Pattern{ predicate: parser.parse_predicate(), word_boundary: word }
	mut t := &parser.tokenizer

	if parser.last_token()? == .tilde {
		pat.word_boundary = true
		parser.next_token()?
	}

	match parser.last_token()? {
		.quoted_text {
			pat.elem = LiteralPattern{ text: t.get_quoted_text() }
			parser.next_token() or {}
		}
		.text {
			pat.elem = NamePattern{ text: t.get_text() }
			parser.next_token() or {}
		}
		.open_bracket, .charset {
			pat.elem = CharsetPattern{ cs: parser.parse_charset()? }
		}
		.open_parentheses {
			parser.next_token()?
			root := GroupPattern{ word_boundary: true }
			pat = parser.parse_compound_expression(root, level + 1)?
			parser.next_token() or {}
		}
		.open_brace {
			parser.next_token()?
			root := GroupPattern{ word_boundary: false }
			pat = parser.parse_compound_expression(root, level + 1)?
			parser.next_token() or {}
		}
		else {
			panic("Should never happen. Unexpected tag in simple expression: '$parser.last_token'")
		}
	}

	parser.parse_multiplier(mut pat)?
	return pat
}

// parse_expression
fn (mut parser Parser) parse_compound_expression(root GroupPattern, level int) ?Pattern {
	if parser.debug > 90 {
		dummy := parser.debug_input()
		eprintln(">> ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}, level=$level, text='${dummy}'")
		defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}, level=$level, text='${dummy}'") }
	}

	mut parent := root
	for !parser.is_end_of_pattern()	{
		mut p := parser.parse_single_expression(root.word_boundary, level)?
		parser.parse_operand(mut p)?
		parent.ar << p
	}

	return Pattern{ elem: parent }
}

fn (mut parser Parser) parse() ? {
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
