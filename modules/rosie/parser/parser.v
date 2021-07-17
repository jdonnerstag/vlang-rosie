module parser

import os

struct Parser {
pub:
	file string
	import_path []string
	debug int

pub mut:
	tokenizer Tokenizer

	language string
	package string

	import_stmts map[string]Import

	bindings map[string]Binding

	last_token Token
}

struct Import {
pub:
	name string
}

struct Binding {
pub:
	public bool
	expr Expression
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

fn (mut p Parser) parse_single_expression() ?Expression {
	eprintln(">> parse_single_expression: tok=$p.last_token, eof=${p.is_eof()}")
	defer { eprintln("<< parse_single_expression: tok=$p.last_token, eof=${p.is_eof()}") }

	mut t := &p.tokenizer

	match p.last_token()? {
		.quoted_text {
			etype := LiteralExpressionType{ text: t.get_quoted_text() }
			p.next_token() or {}
			return p.parse_multiplier(etype)
		}
		.not {
			p.next_token()?
			pe := p.parse_single_expression()?
			if pe.expr is LookAheadExpressionType {
				etype := NegativeLookAheadExpressionType{ p: pe }
				return Expression{ expr: etype, min: pe.min, max: pe.max }
			} else if pe.expr is LookBehindExpressionType {
				etype := NegativeLookBehindExpressionType{ p: pe }
				return Expression{ expr: etype, min: pe.min, max: pe.max }
			}
			etype := NegativeLookAheadExpressionType{ p: pe }
			return p.parse_multiplier(etype)
		}
		.greater {
			p.next_token()?
			etype := LookAheadExpressionType{ p: p.parse_single_expression()? }
			return p.parse_multiplier(etype)
		}
		.smaller {
			p.next_token()?
			etype := LookBehindExpressionType{ p: p.parse_single_expression()? }
			return p.parse_multiplier(etype)
		}
		else {
		}
	}

	return error("Invalid Expression: '$p.last_token'")
}


fn (mut p Parser) parse_multiplier(etype ExpressionType) ?Expression {
	eprintln(">> parse_multiplier: tok=$p.last_token, eof=${p.is_eof()}")
	defer { eprintln("<< parse_multiplier: tok=$p.last_token, eof=${p.is_eof()}") }

	mut min := 1
	mut max := 1

	if !p.is_eof() {
		match p.last_token()? {
			.star {
				min = 0
				max = -1
				p.next_token() or {}
			}
			.plus {
				min = 1
				max = -1
				p.next_token() or {}
			}
			.question_mark {
				min = 0
				max = 1
				p.next_token() or {}
			}
			.open_brace {
				min, max = p.parse_curly_multiplier()?
				p.next_token() or {}
			} else {
			}
		}
	}

	return Expression{ expr: etype, min: min, max: max }
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

fn (mut p Parser) parse_follow_up_expression(expr Expression) ?Expression {
	eprintln(">> parse_follow_up_expression: tok=$p.last_token, eof=${p.is_eof()}")
	defer { eprintln("<< parse_follow_up_expression: tok=$p.last_token, eof=${p.is_eof()}") }

	mut rtn := expr.expr
	match p.last_token()? {
		.quoted_text, .smaller, .greater, .not {
			q := p.parse_single_expression()?
			rtn = SequenceExpressionType{ p: expr, q: q }
		}
		.choice {
			p.next_token()?
			q := p.parse_expression()?
			rtn = ChoiceExpressionType{ p: expr, q: q }
		}
		.ampersand {
			p.next_token()?
			q := p.parse_expression()?
			qe := Expression{ expr: LookBehindExpressionType{ p: expr } }
			rtn = ChoiceExpressionType{ p: qe, q: q }
		}
		else {
			return error("Not yet implemented")
		}
	}
	return Expression{ expr: rtn, min: 1, max: 1, word_boundary: true }
}


fn (mut parser Parser) parse_expression() ?Expression {
	eprintln(">> parse_expression: tok=$parser.last_token, eof=${parser.is_eof()}")
	defer { eprintln("<< parse_expression: tok=$parser.last_token, eof=${parser.is_eof()}") }

	p := parser.parse_single_expression()?

	// No more tokens?
	if parser.is_eof() { return p }

	return parser.parse_follow_up_expression(p)
}
