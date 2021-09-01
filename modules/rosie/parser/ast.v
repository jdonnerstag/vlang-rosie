// ----------------------------------------------------------------------------
// Define the types that make up the AST
// ----------------------------------------------------------------------------

module parser

import rosie.runtime_v2 as rt

// ----------------------------------

pub struct LiteralPattern {
pub:
	text string
}

pub fn (e LiteralPattern) repr() string { return '"$e.text"' }

pub fn (e LiteralPattern) input_len() ? int { return e.text.len }

// ----------------------------------

pub struct NamePattern {
pub:
	text string
}

pub fn (e NamePattern) repr() string { return e.text }

pub fn (e NamePattern) input_len() ? int { return none }

// ----------------------------------

pub struct EofPattern {
pub:
	eof bool	// end-of-file and beginning-of-file
}

pub fn (e EofPattern) repr() string { return if e.eof { "$" } else { "^" } }

pub fn (e EofPattern) input_len() ? int { return 0 }

// ----------------------------------

pub struct CharsetPattern {
pub:
	cs rt.Charset
}

pub fn (e CharsetPattern) repr() string { return '${e.cs.repr()}' }

pub fn (e CharsetPattern) input_len() ? int { return 1 }

// ----------------------------------

pub struct GroupPattern {
pub mut:
	ar []Pattern
	word_boundary bool = true		// Not to be confused with Pattern.word_boundary. Here, it only defines the DEFAULT for operations in the group.
}

pub fn (e GroupPattern) input_len() ? int {
	mut len := 0
	for pat in e.ar {
		len += pat.input_len() or {
			return err
		}
	}
	return len
}

pub fn (e GroupPattern) repr() string {
	mut str := if e.word_boundary { "(" } else { "{" }

	for i in 0 .. e.ar.len {
		if i > 0 {
			str += match e.ar[i - 1].operator {
				.sequence { " " }
				.choice { " / " }
				.conjunction { " & " }
			}
		}

		str += e.ar[i].repr()
	}

	str += if e.word_boundary { ")" } else { "}" }
	return str
}

// ----------------------------------

pub struct MacroPattern {
pub:
	name string
	pat Pattern
}

pub fn (e MacroPattern) repr() string { return '${e.name}:${e.pat.repr()}' }

pub fn (e MacroPattern) input_len() ? int { return none }

// ----------------------------------

pub struct FindPattern {
pub:
	keepto bool
	pat Pattern
}

pub fn (e FindPattern) repr() string {
	alias := if e.keepto { "" } else { "alias "}
	return '
grammar
	$alias<search> = {!${e.pat.repr()} .}*
	<anonymous> = {${e.pat.repr()}}
in
	alias find = {<search> <anonymous>}
end
'
}

pub fn (e FindPattern) input_len() ? int { return none }

// ----------------------------------

pub type PatternElem = LiteralPattern | CharsetPattern | GroupPattern | NamePattern | EofPattern
		| MacroPattern | FindPattern


pub fn (e PatternElem) repr() string {
	return match e {
		LiteralPattern { e.repr() }
		CharsetPattern { e.repr() }
		GroupPattern { e.repr() }
		NamePattern { e.repr() }
		EofPattern { e.repr() }
		MacroPattern { e.repr() }
		FindPattern { e.repr() }
	}
}

pub fn (e PatternElem) input_len() ? int {
	match e {
		LiteralPattern { return e.input_len() }
		CharsetPattern { return e.input_len() }
		GroupPattern { return e.input_len() }
		NamePattern { return e.input_len() }
		EofPattern { return e.input_len() }
		MacroPattern { return e.input_len() }
		FindPattern { return e.input_len() }
	}
}

// ----------------------------------

pub enum PredicateType {
	na
	look_ahead
	negative_look_ahead
	look_behind
	negative_look_behind
}

// ----------------------------------

pub enum OperatorType {
	sequence
	choice
	conjunction
}

// ----------------------------------

pub struct Pattern {
pub mut:
	predicate PredicateType = .na
	elem PatternElem
	min int = 1
	max int = 1							// -1 == '*' == 0, 1, or more
	operator OperatorType = .sequence	// The operator following
	word_boundary bool = true			// The boundary following
	allow_recursion bool				// Only grammars allow recursion
}

pub fn (e Pattern) repr() string {
	mut str := match e.predicate {
		.na { "" }
		.look_ahead { ">" }
		.negative_look_ahead { "!" }
		.look_behind { "<" }
		.negative_look_behind { "!<" }
	}

	str += e.elem.repr()
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
	print_backtrace()
	return error("Pattern is not a GroupPattern: ${p.elem.type_name()}")
}

pub fn new_charset_pattern(str string) Pattern {
	return Pattern{ elem: CharsetPattern{ cs: rt.new_charset_with_chars(str) } }
}

pub fn new_sequence_pattern(word_boundary bool, elems []Pattern) Pattern {
	mut ar := []Pattern{}
	for e in elems {
		mut x := e
		x.word_boundary = word_boundary
		ar << x
	}
	grp := GroupPattern{ word_boundary: word_boundary, ar: ar }
	return Pattern{ word_boundary: word_boundary, elem: grp }
}

pub fn new_choice_pattern(word_boundary bool, elems []Pattern) Pattern {
	mut ar := []Pattern{}
	for e in elems {
		mut x := e
		x.operator = .choice
		x.word_boundary = word_boundary
		ar << x
	}
	grp := GroupPattern{ word_boundary: word_boundary, ar: ar }
	return Pattern{ operator: .choice, word_boundary: word_boundary, elem: grp }
}

pub fn (p Pattern) input_len() ? int {
	if p.predicate != .na {
		return 0
	}

	if l := p.elem.input_len() {
		if p.min == p.max {
			return l
		}
	}

	return none
}
