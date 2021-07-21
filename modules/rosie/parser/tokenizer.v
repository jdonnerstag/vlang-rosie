module parser

import text_scanner

enum Token {
	noop
	open_brace
	close_brace
	open_bracket
	close_bracket
	open_parentheses
	close_parentheses
	equal
	tilde	// '~'
	plus
	star
	not
	smaller
	greater
	double_quote
	single_quote
	comma
	colon
	semicolon
	ampersand
	question_mark
	circumflex
	choice    	// '/'
	text
	quoted_text
	comment
	whitespace
}

const (
	byte_to_enum = init_token_lookup()
	comment_char = "--"
)

fn init_token_lookup() []Token {
	mut lookup := []Token{ len: 256, cap: 256, init: Token.noop }
	lookup[int(`{`)] = .open_brace
	lookup[int(`}`)] = .close_brace
	lookup[int(`[`)] = .open_bracket
	lookup[int(`]`)] = .close_bracket
	lookup[int(`(`)] = .open_parentheses
	lookup[int(`)`)] = .close_parentheses
	lookup[int(`=`)] = .equal
	lookup[int(`~`)] = .tilde
	lookup[int(`+`)] = .plus
	lookup[int(`*`)] = .star
	lookup[int(`"`)] = .double_quote
	lookup[int(`'`)] = .single_quote
	lookup[int(`!`)] = .not
	lookup[int(`<`)] = .smaller
	lookup[int(`>`)] = .greater
	lookup[int(`,`)] = .comma
	lookup[int(`;`)] = .semicolon
	lookup[int(`&`)] = .ampersand
	lookup[int(`/`)] = .choice
	lookup[int(`?`)] = .question_mark
	//lookup[int(`:`)] = .colon
	//lookup[int(`^`)] = .circumflex

	return lookup
}

struct Tokenizer {
pub:
	debug int

pub mut:
	scanner text_scanner.TextScanner
}

pub fn new_tokenizer(data string, debug int) ?Tokenizer {
	scanner := text_scanner.new_scanner(data)?

	return Tokenizer{
		scanner: scanner,
		debug: debug,
	}
}

pub fn (mut ts Tokenizer) get_text() string {
	return ts.scanner.get_text()
}

pub fn (mut ts Tokenizer) peek_text() string {
	return ts.scanner.peek_text()
}

fn (mut ts Tokenizer) is_comment() bool {
	mut s := &ts.scanner

	if s.newline.len == 0 {
		s.newline = text_scanner.detect_newline(s.text) or { "\n" }
	}

	if s.text[s.pos] == `-` {
		s.move_to_eol()
		return true
	}
	return false
}

fn (mut ts Tokenizer) tokenize_quoted_text(qch byte) ?Token {
	mut s := &ts.scanner
	s.pos ++

	for ;!s.is_eof(); s.pos ++ {
		ch := s.at_pos()
		if ch == `\\` {
			s.pos ++
			continue
		}

		if ch == qch {
			s.pos ++
			return .quoted_text
		}

		if text_scanner.is_newline(ch) {
			break
		}
	}

	return error("Quoted string not properly terminated?!?")
}

pub fn (mut ts Tokenizer) next_token() ?Token {
	rtn := ts.internal_next_token()?
	if ts.debug > 2 { eprintln("next_token: $rtn, pos=$ts.scanner.pos, last_pos=$ts.scanner.last_pos, '${ts.peek_text()}'")}
	return rtn
}

fn (mut ts Tokenizer) internal_next_token() ?Token {
	mut s := &ts.scanner
	s.skip_whitespace()
	s.last_pos = s.pos
	if s.is_eof() { return none }

	mut ch := s.at_pos()
	s.pos ++

	if ch == `-` && ts.is_comment() { return .comment }
	if ch == `"` { return ts.tokenize_quoted_text(ch) }

	tok := byte_to_enum[ch]
	if tok != .noop { return tok }

	for ;!s.is_eof(); s.pos ++ {
		ch = s.at_pos()
		if ch.is_space() || byte_to_enum[ch] != .noop { break }
	}

	return Token.text
}

pub fn (mut ts Tokenizer) get_quoted_text() string {
	mut str := ts.get_text()
	str = str[1 .. (str.len - 1)]

	// TODO unescape \00 and friends.
	// See https://gitlab.com/rosie-pattern-language/rosie/blob/d861ffd5805f9988d9ad430e7f124216f11df44e/doc/rpl.md#what-can-i-escape-in-rpl
	str = str.replace("\\", "")

	return str
}
