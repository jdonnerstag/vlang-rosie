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

	locals map[string]string
	aliases map[string]string
	publics map[string]string
}

struct Import {
	name string
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
		str := t.get_text()
		names := str.split(",")
		for n in names {
			name := n.trim_space()
			if name in p.import_stmts {
				return error("Warning: import packages only once: '$name'")
			}
			p.import_stmts[name] = Import{ name: name }
		}

		tok = p.next_token()?
	}
}