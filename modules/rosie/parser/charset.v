module parser

import os
import math
import rosie.runtime as rt
import ystrconv


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
		"$": rt.new_charset(false)
	}
)

fn (mut parser Parser) parse_charset() ?rt.Charset {
	eprintln(">> ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}")
	defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}") }

	if parser.last_token == .charset {
		return parser.parse_charset_token()
	} else if parser.last_token == .open_bracket {
		return parser.parse_charset_bracket()
	}

	return error("Charset: Should never happen. invalid token: .$parser.last_token")
}

fn (mut parser Parser) parse_charset_bracket() ?rt.Charset {
	complement := parser.peek_text("^")
	mut cs := rt.new_charset(false)
	mut op1_union := true
	mut op2_union := true
	mut op1_not := false
	mut op2_not := false

	parser.next_token()?
	for parser.last_token != .close_bracket {
		mut x := rt.new_charset(false)
		match parser.last_token {
			.open_bracket { x = parser.parse_charset_bracket()? }
			.charset { x = parser.parse_charset_token()? }
			.text { x = parser.parse_charset_by_name()? }
			.quoted_text { x = parser.parse_charset_token()? }
			.ampersand {
				op2_union = false
				parser.next_token()?
			}
			.not {
				op2_not = true
				parser.next_token()?
			}
			else { return error("Should never happen: parse_charset_bracket: invalid token: $parser.last_token") }
		}

		if op1_not { x.complement() }
		op1_not = op2_not
		op2_not = false

		if op1_union {
			cs.merge_or(x)
		} else {
			cs.merge_and(x)
		}
		op1_union = op2_union
		op2_union = true
	}

	parser.next_token() or {}
	return if complement { cs.complement() } else { cs }
}

fn (mut parser Parser) parse_charset_token() ?rt.Charset {
	text := parser.tokenizer.get_text()
	parser.next_token() or {}

	if text.len > 2 && text[0] == `:` && text[text.len - 1] == `:` {
		return parser.parse_known_charset(text)
	} else {
		return parser.parse_charset_chars(text)
	}
}

fn (mut parser Parser) parse_known_charset(text string) ?rt.Charset {
	complement := text[1] == `^`

	pos := if complement { 2 } else { 1 }
	name := text[pos .. (text.len - 1)]

	if name.len == 0 {
		return error("Invalid Charset '$text'")
	}

	if !(name in known_charsets) {
		return error("Charset not defined '$text'")
	}

	mut cs := known_charsets[name]
	return if complement { cs.complement() } else { cs }
}

fn (mut parser Parser) parse_charset_chars(text string) ?rt.Charset {
	mut cs := rt.new_charset(false)
	mut str := text.trim_space()
	complement := str.len > 0 && str[0] == `^`

	str = ystrconv.interpolate_double_quoted_string(str, "-")?
	for i := 0; i < str.len; i++ {
		ch := str[i]
		if ch == `\\` && (i + 1) < str.len {
			cs.set_char(str[i + 1])
			i += 1
		} else if ch != `-` {
			cs.set_char(ch)
		} else if i > 0 && (i + 1) < str.len {
			for j in str[i - 1] .. str[i + 1] { cs.set_char(j) }
			i += 2
		} else {
			return error("Invalid Charset '$text'")
		}
	}

	return if complement { cs.complement() } else { cs }
}

fn (mut parser Parser) parse_charset_by_name() ?rt.Charset {
	name := parser.get_text()
	pat := parser.binding(name)?

	mut elem := rt.new_charset(false)
	match pat.elem {
		GroupPattern { elem = (pat.at(0)?.elem as CharsetPattern).cs }
		CharsetPattern { elem = pat.elem.cs }
		else { return error("Charset: unable to find Charset binding for '$name'") }
	}
	return elem
}