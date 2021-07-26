// ----------------------------------------------------------------------------
// Define the types that make up the AST
// ----------------------------------------------------------------------------

module parser

import rosie.runtime as rt

// ----------------------------------

pub struct LiteralPattern {
pub:
	text string
}

pub fn (e LiteralPattern) str() string { return '"$e.text"' }

// ----------------------------------

pub struct NamePattern {
pub:
	text string
}

pub fn (e NamePattern) str() string { return e.text }

// ----------------------------------

pub struct CharsetPattern {
pub:
	cs rt.Charset
}

pub fn (e CharsetPattern) str() string { return '$e.cs' }

// ----------------------------------

pub struct AnyPattern {}

pub fn (e AnyPattern) str() string { return '.' }

// ----------------------------------

pub struct GroupPattern {
pub mut:
	ar []Pattern
	word_boundary bool = true
}

pub fn (e GroupPattern) str() string {
	mut str := if e.word_boundary { "(" } else { "{" }

	for i in 0 .. e.ar.len {
		if i > 0 {
			str += match e.ar[i - 1].operator {
				.sequence { " " }
				.choice { " / " }
				.conjunction { " & " }
			}
			// TODO We are not yet considering "~" !!!
		}

		str += e.ar[i].str()
	}

	str += if e.word_boundary { ")" } else { "}" }
	return str
}

// ----------------------------------

pub type PatternElem = LiteralPattern | CharsetPattern | AnyPattern | GroupPattern | NamePattern

pub fn (e PatternElem) str() string {
	return match e {
		LiteralPattern { e.str() }
		CharsetPattern { e.str() }
		AnyPattern { e.str() }
		GroupPattern { e.str() }
		NamePattern { e.str() }
	}
}

// ----------------------------------

enum PredicateType {
	na
	look_ahead
	negative_look_ahead
	look_behind
	negative_look_behind
}

// ----------------------------------

enum OperatorType {
	sequence
	choice
	conjunction
}

// ----------------------------------

struct Pattern {
pub mut:
	predicate PredicateType = .na
	elem PatternElem
	min int = 1
	max int = 1			// -1 == '*' == 0, 1, or more
	operator OperatorType = .sequence	// The operator following
	word_boundary bool = true			// The boundary followin
}

pub fn (e Pattern) str() string {
	mut str := match e.predicate {
		.na { "" }
		.look_ahead { ">" }
		.negative_look_ahead { "!>" }
		.look_behind { "<" }
		.negative_look_behind { "!<" }
	}
	// TODO Only with sumtype, V always prepend the type name => not consistent
	str += e.elem.str()
	if e.min == 0 && e.max == 1 { str += "?" }
	else if e.min == 1 && e.max == -1 { str += "+" }
	else if e.min == 0 && e.max == -1 { str += "*" }
	else if e.min == 0 && e.max == -1 { str += "*" }
	else if e.min == 1 && e.max == 1 { }
	else if e.max == -1 { str += "{$e.min,}" }
	else { str += "{$e.min,$e.max}" }
	return str
}

// ----------------------------------

// text A utlity function. If the pattern contains a Literal, the return
// the text.
pub fn (p Pattern) text() ?string {
	if p.elem is LiteralPattern {
		return p.elem.text
	}
	return error("Pattern is not a LiteralPattern: ${p.elem.type_name()}")
}

// at A utility function. If the pattern contains a Group, then return the
// pattern at the provided position.
pub fn (p Pattern) at(pos int) ?Pattern {
	if p.elem is GroupPattern {
		if pos >= 0 && pos < p.elem.ar.len {
			return p.elem.ar[pos]
		}
		return error("GroupPattern: Index not found: index=${pos}; len=$p.elem.ar.len")
	}
	return error("Pattern is not a GroupPattern: ${p.elem.type_name()}")
}