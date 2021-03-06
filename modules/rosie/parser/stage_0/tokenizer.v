// ----------------------------------------------------------------------------
// Leveraging the text_scanner, the tokenizer splits the file content into
// tokens relevant for the rpl rosie.
// ----------------------------------------------------------------------------

module stage_0

import text_scanner
import ystrconv

pub enum Token {
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
	semicolon
	colon
	ampersand
	question_mark
	choice    	// '/'
	text
	quoted_text
	comment
	whitespace
	charset		// [..]
	macro   	// find:
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
	lookup[int(`:`)] = .colon

	return lookup
}

struct Tokenizer {
pub:
	debug int

pub mut:
	scanner text_scanner.TextScanner
}

pub fn new_tokenizer(debug int) Tokenizer {
	return Tokenizer { debug: debug }
}

pub fn (mut t Tokenizer) init(data string) ? {
	t.scanner = text_scanner.new_scanner(data)?
}

pub fn (mut ts Tokenizer) get_text() string {
	return ts.scanner.get_text()
}

pub fn (ts Tokenizer) peek_text() string {
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

	for ; !s.is_eof(); s.pos ++ {
		ch := s.at_pos()
		if ch == `\\` {
			s.pos ++
		} else if ch == qch {
			s.pos ++
			return .quoted_text
		} else if text_scanner.is_newline(ch) {
			break
		}
	}

	return error("Quoted string not properly terminated?!?")
}

fn (mut ts Tokenizer) is_charset() bool {
	mut s := &ts.scanner

	pos := s.pos
	for ; !s.is_eof(); s.pos ++ {
		ch := s.at_pos()
		if ch == `]` {
			s.pos ++
			return true
		} else if ch == `\\` {
			s.pos ++
		} else if ch == `[` {
			break
		}
	}

	s.pos = pos
	return false
}

pub fn (mut ts Tokenizer) next_token() ?Token {
	rtn := ts.internal_next_token()?
	if ts.debug > 98 { eprintln("next_token: $rtn, pos=$ts.scanner.pos, last_pos=$ts.scanner.last_pos, '${ts.peek_text()}'")}
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
	if ch == `[` && ts.is_charset() { return .charset }

	tok := byte_to_enum[ch]
	if tok != .noop { return tok }

	for ;!s.is_eof(); s.pos ++ {
		ch = s.at_pos()
		if ch.is_space() || byte_to_enum[ch] != .noop { break }
	}

	if ch == `:` {
		s.pos ++
		return Token.macro
	}

	return Token.text
}

pub fn (mut ts Tokenizer) get_quoted_text() string {
	mut str := ts.get_text()
	//eprintln("quoted text: orig: '$str'")
	str = str[1 .. (str.len - 1)]

	// See https://gitlab.com/rosie-pattern-language/rosie/blob/d861ffd5805f9988d9ad430e7f124216f11df44e/doc/rpl.md#what-can-i-escape-in-rpl
	str = ystrconv.interpolate_double_quoted_string(str, "") or { str }
	//eprintln("quoted text: '$str'")
	return str
}
