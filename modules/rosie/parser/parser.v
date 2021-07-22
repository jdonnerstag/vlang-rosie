module parser

import os
import math
import rosie.runtime as rt

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
	alias bool			// if true, then the pattern is an alias
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

pub fn (parser Parser) print(name string) {
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
	//eprintln(">> ${@FN} '$text': tok=$parser.last_token, eof=${parser.is_eof()}")
	//defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}") }

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
		parser.last_token in [.close_brace, .close_parentheses] ||
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
	p2 := int(math.min(s.text.len, p1 + 30))
	mut str := parser.tokenizer.scanner.text[p1 .. p2]
	str = str.replace("\r\n", "\\n")
	return str
}

fn (mut parser Parser) read_header() ? {
	//eprintln(">> ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}")
	//defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}") }

	parser.next_token()?

	if parser.peek_text("rpl") {
		parser.language = parser.get_text()
	}

	if parser.peek_text("package") {
		parser.package = parser.get_text()
	}

	for parser.peek_text("import") {
		parser.read_import_stmt()?
	}
}

fn (mut parser Parser) read_import_stmt() ? {
	//eprintln(">> ${@FN} '${parser.tokenizer.scanner.text}': tok=$parser.last_token, eof=${parser.is_eof()}")
	//defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}") }

	mut t := &parser.tokenizer
	mut tok := parser.last_token()?

	for true {
		str := if tok == .quoted_text { t.get_quoted_text() } else { t.get_text() }
		if str in parser.import_stmts {
			return error("Warning: import packages only once: '$str'")
		}

		tok = parser.next_token() or {
			parser.import_stmts[str] = Import{ name: str }
			return err
		}

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
	eprintln(">> ${@FN}: '${parser.debug_input()}', tok=$parser.last_token, eof=${parser.is_eof()} -----------------------------------------------------")
	defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}") }

	mut t := &parser.tokenizer

	local := parser.peek_text("local")
	alias := parser.peek_text("alias")
	mut name := "*"

	parser.last_token()?
	if parser.is_assignment() {
		name = t.get_text()
		parser.next_token()?
		parser.next_token()?
	}

	if name in parser.bindings {
		return error("Pattern name already defined: '$name'")
	}

	eprintln("Binding: parse binding for: local=$local, alias=$alias, name='$name'")
	root := GroupPattern{ word_boundary: true }
	pattern := parser.parse_compound_expression(root, 1)?
	parser.bindings[name] = Binding{ public: !local, alias: alias, name: name, pattern: pattern }
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
fn (mut parser Parser) parse_single_expression(word bool, level int) ?Pattern {
	eprintln(">> ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}")
	defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}") }

	mut pat := Pattern{ predicate: parser.parse_predicate(), word_boundary: word }
	mut t := &parser.tokenizer

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

fn (mut parser Parser) parse_multiplier(mut pat Pattern) ? {
	//eprintln(">> ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}")
	//defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}") }

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
	//eprintln(">> ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}")
	//defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}") }

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
	eprintln(">> ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}")
	defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}") }

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

// parse_expression
fn (mut parser Parser) parse_compound_expression(root GroupPattern, level int) ?Pattern {
	dummy := parser.debug_input()
	eprintln(">> ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}, level=$level, text='${dummy}'")
	defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}, level=$level, text='${dummy}'") }

	mut parent := root
	for !parser.is_end_of_pattern()	{
		mut p := parser.parse_single_expression(root.word_boundary, level)?
		parser.parse_operand(mut p)?
		parent.ar << p
	}

	return Pattern{ elem: parent }
}

const (
	// See https://www.gnu.org/software/grep/manual/html_node/Character-Classes-and-Bracket-Expressions.html
	known_charsets = map{
		"alnum": rt.new_charset(false)
		"alpha": rt.new_charset(false)
		"blank": rt.new_charset(false)
		"cntrl": rt.new_charset(false)
		"digit": rt.new_charset(false)
		"graph": rt.new_charset(false)
		"lower": rt.new_charset(false)
		"print": rt.new_charset(false)
		"punct": rt.new_charset(false)
		"space": rt.new_charset(false)
		"upper": rt.new_charset(false)
		"xdigit": rt.new_charset(false)
	}
)

fn (mut parser Parser) parse_charset() ?rt.Charset {
	eprintln(">> ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}")
	defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}") }

	mut cs := rt.new_charset(false)
	mut complement := false

	if parser.last_token == .charset {
		text := parser.tokenizer.get_quoted_text()

		if text.len > 2 && text[0] == `:` && text[text.len - 1] == `:` {
			mut name := ""
			if text[1] == `^` {
				complement = true
				name = text[2 .. (text.len - 1)]
			} else {
				name = text[1 .. (text.len - 1)]
			}

			if name.len == 0 {
				return error("Invalid Charset '$text'")
			}

			if name in known_charsets {
				cs.merge_or(known_charsets[name])
			} else {
				return error("Charset not defined '$text'")
			}
		} else {
			for i := 0; i < text.len; i++ {
				ch := text[i]
				if i == 0 && ch == `^` {
					complement = true
				} else if ch != `-` {
					cs.set_char(ch)
				} else if i > 0 && (i + 1) < text.len {
					ch1 := text[i - 1]
					ch2 := text[i + 1]
					for j in ch1 .. ch2 { cs.set_char(j) }
					i += 2
				} else {
					return error("Invalid Charset '$text'")
				}
			}
		}
	} else if parser.last_token == .open_bracket {
		mut tok := parser.next_token()?

		if parser.peek_text("^") { complement = true }

		for parser.last_token in [.open_bracket, .charset, .text] {
			if parser.last_token in [.open_bracket, .charset] {
				x := parser.parse_charset()?
				cs.merge_or(x)
			} else if parser.last_token == .text {
				name := parser.get_text()
				// TODO Improve error handling
				pat := parser.binding(name)
				x := (pat.at(0)?.elem as CharsetPattern).cs
				cs.merge_or(x)
				tok = parser.next_token()?
			}
		}

		if parser.last_token != .close_bracket {
			return error("Charset: expected ']' but found .$parser.last_token")
		}
	}

	parser.next_token() or {}
	if complement {	cs.complement() }
	return cs
}

fn (mut parser Parser) parse() ? {
	for !parser.is_eof() {
		parser.parse_binding()?
	}
}

fn (mut parser Parser) optimize(pattern Pattern) Pattern {
	return pattern
}