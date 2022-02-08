// ----------------------------------------------------------------------------
// Charset specific parser utils
// ----------------------------------------------------------------------------

module stage_0

import rosie
import ystrconv

// TODO Needs cleanup. Many functions are no longer used !!!!

fn (mut parser Parser) parse_bracket_expression() ?rosie.Charset {
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

fn (mut parser Parser) parse_charset_bracket() ?rosie.Charset {
	parser.next_token()?
	complement := parser.peek_text("^")

	mut cs := rosie.new_charset()
	mut op_union := true
	mut op_not := false

	for parser.last_token != .close_bracket {
		mut x := rosie.new_charset()
		match parser.last_token {
			.open_bracket { x = parser.parse_charset_bracket()? }
			.charset { x = parser.parse_charset_token()? }
			.text {
				name := parser.get_text()
				x = parser.parse_charset_by_name(name)?
			}
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
				return error("Should never happen: parse_charset_bracket: invalid token: .$parser.last_token")
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

fn (mut parser Parser) parse_charset_token() ?rosie.Charset {
	text := parser.tokenizer.get_text()

	parser.next_token() or {}

	if text.starts_with("[:") && text.ends_with(":]") {
		return parser.parse_known_charset(text)
	} else {
		return parser.parse_charset_chars(text)
	}
}

fn (mut parser Parser) parse_known_charset(text string) ?rosie.Charset {
	complement := text[2] == `^`

	pos := if complement { 3 } else { 2 }
	name := text[pos .. (text.len - 2)]

	if name.len == 0 {
		return error("Charset name cannot be empty '$text'")
	}

	if !(name in rosie.known_charsets) {
		return error("Charset not defined '$text'")
	}

	cs := rosie.known_charsets[name]
	return if complement { cs.complement() } else { cs }
}

fn (mut parser Parser) parse_charset_chars(text string) ?rosie.Charset {

	str := ystrconv.interpolate_double_quoted_string(text, "-")?
	complement := str.len > 0 && str[1] == `^`

	mut i := if complement { 2 } else { 1 }
	mut cs := rosie.new_charset()

	for ; i < (str.len - 1); i++ {
		ch := str[i]
		if ch == `\\` && str[i + 1] == `-` {
			cs.set_char(`-`)
			i += 1
		} else if ch != `-` {
			cs.set_char(ch)
		} else if i > 0 && (i + 1) < str.len {
			for j := str[i - 1]; j <= str[i + 1]; j++ { cs.set_char(j) }
			i += 2
		} else {
			return error("Invalid Charset '$text'")
		}
	}

	return if complement { cs.complement() } else { cs }
}

fn (mut parser Parser) parse_charset_by_name(name string) ?rosie.Charset {
	pat := parser.pattern(name)?
	match pat.elem {
		rosie.GroupPattern {
			p := pat.at(0)?
			if p.elem is rosie.CharsetPattern {
				return p.elem.cs
			} else {
				return error("Group's first elem is not a Charset: '$name' ${p.elem.type_name()}")
			}
		}
		rosie.CharsetPattern {
			return pat.elem.cs
		}
		else {
			return error("Charset: unable to find Charset binding for '$name'")
		}
	}
}

fn merge_charsets(mut elem rosie.DisjunctionPattern) {
	if elem.ar.len > 0 {
		e := elem.ar[0].elem
		if e is rosie.EofPattern {
			if e.eof == false {
				elem.negative = true
				elem.ar.delete(0)
			}
		}
	}

/* TODO Must be done later. In expand()?
	for mut e in elem.ar {
		if e.elem is rosie.NamePattern {
			b := rosie.binding(b.elem.name)?
			if b.pattern.elem is rosie.CharsetPattern {
				e.elem = b.pattern.elem
			}
		}
	}
*/
	if elem.ar.len > 1 {
		for i := 0; i < elem.ar.len - 1; i++ {
			a1 := elem.ar[i].elem
			a2 := elem.ar[i + 1].elem
			if a1 is rosie.CharsetPattern && a2 is rosie.CharsetPattern {
				cs := a1.cs.merge_or(a2.cs)
				elem.ar[i].elem = rosie.CharsetPattern{ cs: cs }
				elem.ar.delete(i + 1)
				i -= 1
			}
		}
	}

	if elem.negative && elem.ar.len == 1 {
		if elem.ar[0].elem is rosie.CharsetPattern {
			elem.negative = false
			elem.ar[0].elem = rosie.CharsetPattern{ cs: elem.ar[0].elem.cs.complement() }
		}
	}
}
