// ----------------------------------------------------------------------------
// Charset specific parser utils
// ----------------------------------------------------------------------------

module parser

import rosie.runtime as rt
import ystrconv


const (
	cs_alnum = rt.new_charset_with_chars("0-9A-Za-z")
	cs_punct = rt.new_charset_with_chars(r"!#$%&'()*+,\-./:;<=>?@[\]^_`{|} ~" + '"')

	// See https://www.gnu.org/software/grep/manual/html_node/Character-Classes-and-Bracket-Expressions.html
	known_charsets = map{
		"alnum": cs_alnum
		"alpha": rt.new_charset_with_chars("A-Za-z")
		"blank": rt.new_charset_with_chars(" \t")
		"cntrl": rt.new_charset_with_chars("\000-\037\177")
		"digit": rt.new_charset_with_chars("0-9")
		"graph": cs_alnum.copy().merge_or(cs_punct)
		"lower": rt.new_charset_with_chars("a-z")
		"print": cs_alnum.copy().merge_or(cs_punct).merge_or(rt.new_charset_with_chars(" "))
		"punct": cs_punct
		"space": rt.new_charset_with_chars("\t\n\f\r\v ")
		"upper": rt.new_charset_with_chars("A-Z")
		"xdigit": rt.new_charset_with_chars("0-9A-Fa-f")
		"word": rt.new_charset_with_chars("0-9A-Za-z_")
		"ascii": rt.new_charset_with_chars("\000-\177")	 // 0 - 127
		"$": rt.new_charset_with_chars("\r\n")
	}
)

fn (mut parser Parser) parse_charset() ?rt.Charset {
	if parser.debug > 98 {
		eprintln(">> ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}")
		defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}") }
	}

	if parser.last_token == .charset {
		return parser.parse_charset_token()
	} else if parser.last_token == .open_bracket {
		return parser.parse_charset_bracket()
	}

	return error("Charset: Should never happen. invalid token: .$parser.last_token")
}

fn (mut parser Parser) parse_charset_bracket() ?rt.Charset {
	parser.next_token()?
	complement := parser.peek_text("^")

	mut cs := rt.new_charset(false)
	mut op_union := true
	mut op_not := false

	for parser.last_token != .close_bracket {
		mut x := rt.new_charset(false)
		match parser.last_token {
			.open_bracket { x = parser.parse_charset_bracket()? }
			.charset { x = parser.parse_charset_token()? }
			.text { x = parser.parse_charset_by_name()? }
			.quoted_text { x = parser.parse_charset_token()? }
			.ampersand {
				op_union = false
				parser.next_token()?
				continue
			}
			.not {
				op_not = true
				parser.next_token()?
				continue
			}
			else {
				return error("Should never happen: parse_charset_bracket: invalid token: $parser.last_token")
			}
		}

		if op_not { x = x.complement() }
		op_not = false

		cs = if op_union { cs.merge_or(x) } else { cs.merge_and(x) }
		op_union = true
	}

	parser.next_token() or {}
	return if complement { cs.complement() } else { cs }
}

fn (mut parser Parser) parse_charset_token() ?rt.Charset {
	text := parser.tokenizer.get_text()

	parser.next_token() or {}

	if text.starts_with("[:") && text.ends_with(":]") {
		return parser.parse_known_charset(text)
	} else {
		return parser.parse_charset_chars(text)
	}
}

fn (mut parser Parser) parse_known_charset(text string) ?rt.Charset {
	complement := text[2] == `^`

	pos := if complement { 3 } else { 2 }
	name := text[pos .. (text.len - 2)]

	if name.len == 0 {
		return error("Charset name cannot be empty '$text'")
	}

	if !(name in known_charsets) {
		return error("Charset not defined '$text'")
	}

	mut cs := known_charsets[name]
	return if complement { cs.complement() } else { cs }
}

fn (mut parser Parser) parse_charset_chars(text string) ?rt.Charset {

	str := ystrconv.interpolate_double_quoted_string(text, "-")?
	complement := str.len > 0 && str[1] == `^`

	mut i := if complement { 2 } else { 1 }
	mut cs := rt.new_charset(false)

	for ; i < (str.len - 1); i++ {
		ch := str[i]
		if ch == `\\` && (i + 1) < str.len {
			cs.set_char(str[i + 1])
			i += 1
		} else if ch != `-` {
			cs.set_char(ch)
		} else if i > 0 && (i + 1) < str.len {
			for j in str[i - 1] .. (str[i + 1] + 1) { cs.set_char(j) }
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

	match pat.elem {
		GroupPattern { return (pat.at(0)?.elem as CharsetPattern).cs }
		CharsetPattern { return pat.elem.cs }
		else { return error("Charset: unable to find Charset binding for '$name'") }
	}
}