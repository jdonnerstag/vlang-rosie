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
	import_stmts map[string]Import	// alias => details
	bindings map[string]Binding		// name => expression
	expressions []Expression		// The list of all the expression elements

	last_token Token
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

pub fn (b Binding) expr(p Parser) &Expression {
	return &p.expressions[b.expr]
}

pub fn (b Binding) str() string {
	return "Binding: pub=$b.public, idx=$b.expr"
}

pub fn (p Parser) binding(name string) &Expression {
	return p.bindings[name].expr(p)
}

pub fn (pe Expression) sub(p Parser, idx int) &Expression {
	return &p.expressions[pe.subs[idx]]
}

pub fn (mut p Parser) print(name string) {
	b := p.bindings[name]
	eprintln("${b}, name='$name'")
	p.expressions[b.expr].print(p, 1)
}

pub fn (mut p Parser) next_token() ?Token {
	mut tok := p.tokenizer.next_token()?
	for tok == .comment || (tok == .text && p.tokenizer.peek_text().len == 0) {
		tok = p.tokenizer.next_token()?
	}
	p.last_token = tok
	return tok
}

[inline]
fn (mut p Parser) is_eof() bool {
	s := &p.tokenizer.scanner
	return s.last_pos >= s.text.len
}

fn (mut p Parser) last_token() ?Token {
	if p.is_eof() { return none }
	return p.last_token
}

fn (mut p Parser) read_header() ? {
	mut t := &p.tokenizer

	mut tok := p.next_token()?
	if tok == .text && t.peek_text() == "rpl" {
		tok = p.next_token()?
		p.language = t.get_text()
		tok = p.next_token()?
	}

	if tok == .text && t.peek_text() == "package" {
		tok = p.next_token()?
		p.package = t.get_text()
		tok = p.next_token()?
	}

	for tok == .text && t.peek_text() == "import" {
		tok = p.next_token()?
		for true {
			str := if tok == .quoted_text { t.get_quoted_text() } else { t.get_text() }
			if str in p.import_stmts {
				return error("Warning: import packages only once: '$str'")
			}

			tok = p.next_token() or {
				p.import_stmts[str] = Import{ name: str }
				return err
			}

			if tok == .text && t.peek_text() == "as" {
				tok = p.next_token()?
				alias := t.get_text()
				p.import_stmts[alias] = Import{ name: str }
				tok = p.next_token() or { break }
			} else {
				p.import_stmts[str] = Import{ name: str }
			}

			if tok != .comma { break }

			tok = p.next_token()?
		}
	}
}

fn (mut p Parser) add_expr(pe Expression) int {
	eprintln("add expr: $pe")
	pos := p.expressions.len
	p.expressions << pe
	return pos
}

fn (mut p Parser) parse_binding() ? {
	eprintln(">> parse_binding '${p.tokenizer.scanner.text}': tok=$p.last_token, eof=${p.is_eof()} ------------------")
	defer { eprintln("<< parse_binding: tok=$p.last_token, eof=${p.is_eof()}") }

	mut t := &p.tokenizer

	mut local := false
	mut alias := false
	mut name := ""

	mut tok := p.last_token()?
	if tok == .text && t.peek_text() == "local" {
		local = true
		tok = p.next_token()?
	}

	if tok == .text && t.peek_text() == "alias" {
		alias = true
		tok = p.next_token()?
	}

	if alias == false {
		name = "*"
	} else if tok == .text  {
		name = t.get_text()
		tok = p.next_token()?

		if tok == .equal {
			tok = p.next_token()?
		} else {
			return error("Expected to find a '='")
		}
	} else {
		return error("Expected to find a pattern name. Found: '$tok' instead")
	}

	if name in p.bindings {
		return error("Pattern name already defined: '$name'")
	}

	expr := p.parse_expression()?
	p.bindings[name] = Binding{ public: !local, expr: expr }
	eprintln("parse_bindung: name=$name, '${p.bindings[name]}'")
}

fn (mut p Parser) parse_single_expression() ?int {
	eprintln(">> parse_single_expression: tok=$p.last_token, eof=${p.is_eof()}, len=$p.expressions.len")
	defer { eprintln("<< parse_single_expression: tok=$p.last_token, eof=${p.is_eof()}, len=$p.expressions.len") }

	mut t := &p.tokenizer

	match p.last_token()? {
		.quoted_text {
			expr := p.add_expr(Expression{ etype: .literal, text: t.get_quoted_text() })
			p.next_token() or {}
			return p.parse_multiplier(expr)
		}
		.not {
			p.next_token()?
			pe_idx := p.parse_single_expression()?
			mut pe := &p.expressions[pe_idx]
			pe.etype = match pe.etype {
				.look_ahead { ExpressionType.negative_look_ahead }
				.look_behind { ExpressionType.negative_look_behind }
				else { ExpressionType.negative_look_ahead }
			}
			return p.parse_multiplier(pe_idx)
		}
		.greater {
			p.next_token()?
			pe_idx := p.parse_single_expression()?
			p.expressions[pe_idx].etype = .look_ahead
			return p.parse_multiplier(pe_idx)
		}
		.smaller {
			p.next_token()?
			pe_idx := p.parse_single_expression()?
			p.expressions[pe_idx].etype = .look_behind
			return p.parse_multiplier(pe_idx)
		}
		else {}
	}

	return error("Invalid Expression: '$p.last_token'")
}


fn (mut p Parser) parse_multiplier(pe_idx int) ?int {
	eprintln(">> parse_multiplier: tok=$p.last_token, eof=${p.is_eof()}")
	defer { eprintln("<< parse_multiplier: tok=$p.last_token, eof=${p.is_eof()}") }

	mut pe := &p.expressions[pe_idx]

	if !p.is_eof() {
		match p.last_token()? {
			.star {
				pe.min = 0
				pe.max = -1
				p.next_token() or {}
			}
			.plus {
				pe.min = 1
				pe.max = -1
				p.next_token() or {}
			}
			.question_mark {
				pe.min = 0
				pe.max = 1
				p.next_token() or {}
			}
			.open_brace {
				pe.min, pe.max = p.parse_curly_multiplier()?
				p.next_token() or {}
			} else {}
		}
	}
	return pe_idx
}

fn (mut p Parser) parse_curly_multiplier() ?(int, int) {
	eprintln(">> parse_curly_multiplier: tok=$p.last_token, eof=${p.is_eof()}")
	defer { eprintln("<< parse_curly_multiplier: tok=$p.last_token, eof=${p.is_eof()}") }

	mut t := &p.tokenizer
	mut min := 1
	mut max := 1

	mut tok := p.next_token()?	// skip '{'
	if tok == .comma {
		min = 0
		tok = p.next_token()?
	} else {
		min = t.get_text().int()
		tok = p.next_token()?
		if tok == .comma { tok = p.next_token()? }
	}

	if tok == .close_brace {
		max = -1
	} else {
		max = t.get_text().int()
		tok = p.next_token()?
		if tok != .close_brace {
			return error("Expected '}' to close multiplier: '$tok'")
		}
	}

	p.next_token() or {}
	return min, max
}

fn (mut p Parser) parse_follow_up_expression(pe_idx int) ?int {
	eprintln(">> parse_follow_up_expression: tok=$p.last_token, eof=${p.is_eof()}, pe=${p.expressions[pe_idx]}")
	defer { eprintln("<< parse_follow_up_expression: tok=$p.last_token, eof=${p.is_eof()}") }

	mut pe := &p.expressions[pe_idx]
	eprintln("pe.etype=$pe.etype")
	mut rtn := pe_idx
	match p.last_token()? {
		.quoted_text, .smaller, .greater, .not {
			q := p.parse_single_expression()?
			if pe.etype == .sequence {
				pe.subs << q
			} else {
				rtn = p.add_expr(Expression{ etype: .sequence, subs: [pe_idx, q] })
			}
		}
		.choice {
			p.next_token()?
			qe_idx := p.parse_expression()?
			mut qe := &p.expressions[qe_idx]
			eprintln("p: $pe")
			eprintln("q: $qe")
			if qe.etype == .choice {
				qe.subs.prepend(pe_idx)
				rtn = qe_idx
			} else {
				rtn = p.add_expr(Expression{ etype: .choice, subs: [pe_idx, qe_idx] })
			}
		}
		.ampersand {
			p.next_token()?
			pe.etype = .look_ahead
			pe.word_boundary = false
			q := p.parse_expression()?
			rtn = p.add_expr(Expression{ etype: .sequence, subs: [pe_idx, q] })
		}
		else {
			return error("Not yet implemented")
		}
	}
	return rtn
}

fn (mut parser Parser) parse_expression() ?int {
	eprintln(">> parse_expression: tok=$parser.last_token, eof=${parser.is_eof()}")
	defer { eprintln("<< parse_expression: tok=$parser.last_token, eof=${parser.is_eof()}") }

	mut p := parser.parse_single_expression()?

	// No more tokens?
	if parser.is_eof() { return p }

	for {
		p = parser.parse_follow_up_expression(p) or { break }
	}
	return p
}
