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

	expressions []Expression		// Master-list of all the expressions

	last_token Token				// temp
}

struct Import {
pub:
	name string		// Package path
}

struct Binding {
pub:
	public bool		// if true, then the pattern is public
	expr int		// The expression, the name is referring to
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
pub fn (b Binding) expr(parser Parser) &Expression {
	return parser.expr(b.expr)
}

//[inline]
pub fn (b Binding) str() string {
	return "Binding: pub=$b.public, idx=$b.expr"
}

//[inline]
pub fn (parser Parser) binding(name string) &Expression {
	return parser.bindings[name].expr(parser)
}

//[inline]
pub fn (parser Parser) expr(idx int) &Expression {
	return &parser.expressions[idx]
}

//[inline]
pub fn (expr Expression) sub(parser Parser, idx int) &Expression {
	return &parser.expressions[expr.subs[idx]]
}

pub fn (mut parser Parser) print(name string) {
	b := parser.bindings[name]
	eprintln("${b}, name='$name'")
	if b.expr >= 0 && b.expr < parser.expressions.len {
		parser.expressions[b.expr].print(parser, 1)
	} else {
		eprintln("ERROR: No expression yet assigned to binding. Expression parsing failed?")
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
fn (mut parser Parser) is_eof() bool {
	s := &parser.tokenizer.scanner
	return s.last_pos >= s.text.len
}

//[inline]
fn (mut parser Parser) last_token() ?Token {
	if parser.is_eof() { return none }
	return parser.last_token
}

fn (mut parser Parser) read_header() ? {
	mut t := &parser.tokenizer

	mut tok := parser.next_token()?
	if tok == .text && t.peek_text() == "rpl" {
		tok = parser.next_token()?
		parser.language = t.get_text()
		tok = parser.next_token()?
	}

	if tok == .text && t.peek_text() == "package" {
		tok = parser.next_token()?
		parser.package = t.get_text()
		tok = parser.next_token()?
	}

	for tok == .text && t.peek_text() == "import" {
		tok = parser.next_token()?
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

		if tok == .text && t.peek_text() == "as" {
			tok = parser.next_token()?
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

fn (mut parser Parser) add_expr(expr Expression) int {
	eprintln("add expr: $expr")
	pos := parser.expressions.len
	parser.expressions << expr
	return pos
}

fn (mut parser Parser) parse_binding() ? {
	eprintln(">> parse_binding '${parser.tokenizer.scanner.text}': tok=$parser.last_token, eof=${parser.is_eof()} -----------------------------------------------------")
	defer { eprintln("<< parse_binding: tok=$parser.last_token, eof=${parser.is_eof()}") }

	mut t := &parser.tokenizer

	mut local := false
	mut alias := false
	mut name := ""

	mut tok := parser.last_token()?
	if tok == .text && t.peek_text() == "local" {
		local = true
		tok = parser.next_token()?
	}

	if tok == .text && t.peek_text() == "alias" {
		alias = true
		tok = parser.next_token()?
	}

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

	parent_idx := parser.add_expr(operator: .sequence)
	root := parser.parse_expression(parent_idx)?
	parser.bindings[name] = Binding{ public: !local, expr: root }

	parser.print(name)
}

// parse_single_expression This is to parse a simple expression, such as
// "aa", !"bb" !<"cc", "dd"*, [:digit:]+ etc.
fn (mut parser Parser) parse_single_expression() ?int {
	eprintln(">> parse_single_expression: tok=$parser.last_token, eof=${parser.is_eof()}, len=$parser.expressions.len")
	defer { eprintln("<< parse_single_expression: tok=$parser.last_token, eof=${parser.is_eof()}, len=$parser.expressions.len") }

	mut t := &parser.tokenizer
	mut rtn := -1

	match parser.last_token()? {
		.quoted_text {
			rtn = parser.add_expr(pattern: .literal, text: t.get_quoted_text())
			parser.next_token() or {}
		}
		.not {
			parser.next_token()?
			rtn = parser.parse_single_expression()?
			mut pe := parser.expr(rtn)
			pe.predicate = match pe.predicate {
				.look_ahead { PredicateType.negative_look_ahead }
				.look_behind { PredicateType.negative_look_behind }
				else { PredicateType.negative_look_ahead }
			}
		}
		.greater {
			parser.next_token()?
			rtn = parser.parse_single_expression()?
			parser.expr(rtn).predicate = .look_ahead
		}
		.smaller {
			parser.next_token()?
			rtn = parser.parse_single_expression()?
			parser.expr(rtn).predicate = .look_behind
		}
		.open_bracket {
			return error("Charsets such as [:digit:] are not yet implemented")
		}
		else {
			panic("Should never happen. Unexpected tag in simple expression: '$parser.last_token'")
		}
	}

	return parser.parse_multiplier(rtn)
}

fn (mut parser Parser) parse_multiplier(idx int) ?int {
	eprintln(">> parse_multiplier: tok=$parser.last_token, eof=${parser.is_eof()}")
	defer { eprintln("<< parse_multiplier: tok=$parser.last_token, eof=${parser.is_eof()}") }

	mut pe := parser.expr(idx)

	if !parser.is_eof() {
		match parser.last_token()? {
			.star {
				pe.min = 0
				pe.max = -1
				parser.next_token() or {}
			}
			.plus {
				pe.min = 1
				pe.max = -1
				parser.next_token() or {}
			}
			.question_mark {
				pe.min = 0
				pe.max = 1
				parser.next_token() or {}
			}
			.open_brace {
				pe.min, pe.max = parser.parse_curly_multiplier()?
				parser.next_token() or {}
			} else {}
		}
	}
	return idx
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

// parse_expression
fn (mut parser Parser) parse_compound_expression(parent_idx int) ?int {
	eprintln(">> parse_compound_expression: tok=$parser.last_token, eof=${parser.is_eof()}, parent=${parser.expressions[parent_idx]}")
	defer { eprintln("<< parse_compound_expression: tok=$parser.last_token, eof=${parser.is_eof()}") }

	mut parent := parser.expr(parent_idx)
	eprintln("parent=$parent")
	mut rtn := parent_idx
	match parser.last_token()? {
		.quoted_text, .smaller, .greater, .not {
			pe := parser.parse_single_expression()?
			if parser.is_eof() {
				eprintln("111")
				//parent.subs << pe		// TODO I don#t understand why this is not working !?!?!
				parser.expressions[parent_idx].subs << pe
				eprintln("parent=$parent")
			} else {
				match parser.last_token()? {
					.choice {
						if parent.operator == .choice || parent.subs.len == 0 {
							eprintln("222")
							parser.expressions[parent_idx].operator = .choice
							parser.expressions[parent_idx].subs << pe
						} else {
							eprintln("333")
							rtn = parser.add_expr(operator: .choice)
							parser.expressions[parent_idx].subs << rtn
							parser.expressions[rtn].subs << pe
						}
					}
					.ampersand {
						eprintln("444")
						rtn = parser.add_expr(operator: .conjunction)
						parser.expressions[rtn].subs << pe
					}
					else {
						if parent.operator == .sequence || parent.subs.len == 0 {
							eprintln("555")
							parser.expressions[parent_idx].operator = .sequence
							parser.expressions[parent_idx].subs << pe
						} else {
							eprintln("666")
							rtn = parser.add_expr(operator: .sequence)
							parser.expressions[parent_idx].subs << rtn
							parser.expressions[rtn].subs << pe
						}
					}
				}
			}
		}
		.choice {
			parser.next_token()?
		}
		.ampersand {
			parser.next_token()?
		}
		/*
		.open_parentheses {
			parser.next_token()?
			// How to find the parent?
			return parser.parse_multiplier(pe_idx)
		}
		.close_parentheses {
			parser.next_token()?
			// How to find the parent?
			return parser.parse_multiplier(pe_idx)
		}
		*/
		else {
			return error("Not yet implemented: .$parser.last_token")
		}
	}
	return rtn

}

fn (mut parser Parser) parse_expression(parent_idx int) ?int {
	eprintln(">> parse_expression: tok=$parser.last_token, eof=${parser.is_eof()}")
	defer { eprintln("<< parse_expression: tok=$parser.last_token, eof=${parser.is_eof()}") }

	mut pe := parser.parse_compound_expression(parent_idx)?
	eprintln("pe=${parser.expr(pe)}")
	for !parser.is_eof() {
		pe = parser.parse_compound_expression(parent_idx)?
		eprintln("pe=${parser.expr(pe)}")
	}
/*
	pe := parser.expr(parent_idx)
	if pe.subs.len == 1 && pe.sub(parser, 0).pattern != .na {
		return pe.subs[0]
	}
*/
	eprintln("pe=${parser.expr(pe)}")
	return pe
}
