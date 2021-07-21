module parser

import os

struct Parser {
pub:
	file string
	import_path []string
	debug int

pub mut:
	tokenizer Tokenizer

	language string					// e.g. rpl 1.0 => "1.0"
	package string					// e.g. package net => "net"
	import_stmts map[string]Import	// alias => full name
	bindings map[string]Binding		// name => expression

	last_token Token				// temp
}

struct Import {
pub:
	name string		// Package path
}

struct Binding {
pub:
	name string
	public bool			// if true, then the pattern is public
	pattern Pattern		// The pattern, the name is referring to
}

struct ParserOptions {
	fpath string
	data string
	debug int
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
	}

	parser.read_header()?
	return parser
}

//[inline]
pub fn (b Binding) str() string {
	str := if b.public { "public" } else { "local" }
	return "Binding: $str $b.name=$b.pattern"
}

//[inline]
pub fn (parser Parser) binding(name string) &Pattern {
	return &parser.bindings[name].pattern
}

pub fn (mut parser Parser) print(name string) {
	eprintln(parser.bindings[name])
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
fn (mut parser Parser) is_eof() bool {
	s := &parser.tokenizer.scanner
	return s.last_pos >= s.text.len
}

//[inline]
fn (mut parser Parser) last_token() ?Token {
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

fn (mut parser Parser) read_header() ? {
	mut tok := parser.next_token()?

	if parser.peek_text("rpl") {
		parser.language = parser.get_text()
	}

	if parser.peek_text("package") {
		parser.package = parser.get_text()
	}

	for parser.peek_text("import") {
		parser.read_import_stmt(tok)?
	}
}

fn (mut parser Parser) read_import_stmt(token Token) ? {
	mut t := &parser.tokenizer
	mut tok := token

	for true {
		str := if tok == .quoted_text { t.get_quoted_text() } else { t.get_text() }
		if str in parser.import_stmts {
			return error("Warning: import packages only once: '$str'")
		}

		tok = parser.next_token() or {
			parser.import_stmts[str] = Import{ name: str }
			return err
		}

		// TODO Use the helper methods from above
		if parser.peek_text("as") {
			alias := t.get_text()
			parser.import_stmts[alias] = Import{ name: str }
			tok = parser.next_token() or { break }
		} else {
			parser.import_stmts[str] = Import{ name: str }
		}

		if tok != .comma { break }

		tok = parser.next_token()?
	}
}

fn (mut parser Parser) parse_binding() ? {
	eprintln(">> parse_binding '${parser.tokenizer.scanner.text}': tok=$parser.last_token, eof=${parser.is_eof()} -----------------------------------------------------")
	defer { eprintln("<< parse_binding: tok=$parser.last_token, eof=${parser.is_eof()}") }

	mut t := &parser.tokenizer

	local := parser.peek_text("local")
	alias := parser.peek_text("alias")
	mut name := ""

	mut tok := parser.last_token()?
	if alias == false {
		name = "*"
	} else if tok == .text  {
		name = t.get_text()
		tok = parser.next_token()?

		if tok == .equal {
			tok = parser.next_token()?
		} else {
			return error("Expected to find a '='")
		}
	} else {
		return error("Expected to find a pattern name. Found: '$tok' instead")
	}

	if name in parser.bindings {
		return error("Pattern name already defined: '$name'")
	}

	root := GroupPattern{ word_boundary: true }
	pattern := parser.parse_compound_expression(root)?
	parser.bindings[name] = Binding{ public: !local, name: name, pattern: pattern }
	parser.print(name)
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

// parse_single_expression This is to parse a simple expression, such as
// "aa", !"bb" !<"cc", "dd"*, [:digit:]+ etc.
fn (mut parser Parser) parse_single_expression(word bool) ?Pattern {
	eprintln(">> parse_single_expression: tok=$parser.last_token, eof=${parser.is_eof()}")
	defer { eprintln("<< parse_single_expression: tok=$parser.last_token, eof=${parser.is_eof()}") }

	mut pat := Pattern{ predicate: parser.parse_predicate(), word_boundary: word }
	mut t := &parser.tokenizer

	match parser.last_token()? {
		.quoted_text {
			pat.elem = LiteralPattern{ text: t.get_quoted_text() }
			parser.next_token() or {}
		}
		.open_bracket {
			return error("Charsets such as [:digit:] are not yet implemented")
		}
		.open_parentheses {
			parser.next_token()?
			root := GroupPattern{ word_boundary: true }
			pat = parser.parse_compound_expression(root)?
			parser.next_token() or {}
		}
		.open_brace {
			parser.next_token()?
			root := GroupPattern{ word_boundary: false }
			pat = parser.parse_compound_expression(root)?
			parser.next_token() or {}
		}
		else {
			panic("Should never happen. Unexpected tag in simple expression: '$parser.last_token'")
		}
	}

	parser.parse_multiplier(mut pat)?
	return pat
}

fn (mut parser Parser) parse_multiplier(mut pat Pattern) ? {
	eprintln(">> parse_multiplier: tok=$parser.last_token, eof=${parser.is_eof()}")
	defer { eprintln("<< parse_multiplier: tok=$parser.last_token, eof=${parser.is_eof()}") }

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
					parser.next_token() or {}
				}
			} else {}
		}
	}
}

fn (mut parser Parser) parse_curly_multiplier() ?(int, int) {
	eprintln(">> parse_curly_multiplier: tok=$parser.last_token, eof=${parser.is_eof()}")
	defer { eprintln("<< parse_curly_multiplier: tok=$parser.last_token, eof=${parser.is_eof()}") }

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

fn (mut parser Parser) parse_operand() ?OperatorType {
	eprintln(">> parse_operand: tok=$parser.last_token, eof=${parser.is_eof()}")
	defer { eprintln("<< parse_operand: tok=$parser.last_token, eof=${parser.is_eof()}") }

	match parser.last_token {
		.choice {
			parser.next_token()?
			return OperatorType.choice
		}
		.ampersand {
			parser.next_token()?
			return OperatorType.conjunction
		}
		else {
			return OperatorType.sequence
		}
	}
}

// parse_expression
fn (mut parser Parser) parse_compound_expression(root GroupPattern) ?Pattern {
	eprintln(">> parse_compound_expression: tok=$parser.last_token, eof=${parser.is_eof()}")
	defer { eprintln("<< parse_compound_expression: tok=$parser.last_token, eof=${parser.is_eof()}") }

	parser.print("*")

	mut parent := root
	for !parser.is_eof() && !(parser.last_token in [.close_brace, .close_parentheses]) {
		mut p := parser.parse_single_expression(root.word_boundary)?
		p.operator = parser.parse_operand()?
		parent.ar << p
	}

	return Pattern{ elem: parent }
}

fn (mut parser Parser) optimize(pattern Pattern) Pattern {
	return pattern
}