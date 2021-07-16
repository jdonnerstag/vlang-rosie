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
	eprintln("next_token: $tok, '${p.tokenizer.peek_text()}'")
	return tok
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
	mut t := &p.tokenizer

	mut local := false
	mut alias := false
	mut name := ""

	mut tok := p.last_token
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
		alias = true
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

	expr := p.parse_expression()?
	p.bindings[name] = Binding{ public: !local, expr: expr }
}

fn (mut p Parser) parse_expression() ?Expression {
	mut t := &p.tokenizer

	mut tok := p.last_token
	if tok == .quoted_text {
		etype := LiteralExpressionType{ text: t.get_quoted_text() }
		return Expression{ expr: etype, min: 1, max: 1}
	}

	return error("Invalid Expression")
}