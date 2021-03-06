// ----------------------------------------------------------------------------
// Define the types that make up the AST
// ----------------------------------------------------------------------------

module rosie

// ----------------------------------

pub struct NonePattern { }

pub fn (e NonePattern) repr() string { return '' }

pub fn (e NonePattern) input_len() ? int { return none }

// ----------------------------------

pub struct LiteralPattern {
pub:
	text string
}

pub fn (e LiteralPattern) repr() string {
	str := e.text.replace("\n", "\\n").replace("\r", "\\r")
	return '"$str"'
}

pub fn (e LiteralPattern) input_len() ? int { return e.text.len }

// ----------------------------------

pub struct NamePattern {
pub:
	name string
}

pub fn (e NamePattern) repr() string { return e.name }

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
pub mut:
	cs Charset
}

pub fn (e CharsetPattern) repr() string {
	return e.cs.repr().replace("\n", "\\n").replace("\r", "\\r")
}

pub fn (e CharsetPattern) input_len() ? int { return 1 }

// ----------------------------------

pub struct GroupPattern {
pub mut:
	ar []Pattern
	word_boundary bool = true
}

pub fn (e GroupPattern) input_len() ? int {
	// Please note that by ignoring word_boundary, we determine the
	// shortest possible input_len.
	mut len := 0
	for pat in e.ar {
		//eprintln("pat: ${pat.repr()}")
		if pat.predicate == .na {
			if pat.operator == .sequence {
				len += pat.input_len() or {
					return err
				}
			} else {
				return none
			}
		}
	}
	return len
}

pub fn (e GroupPattern) repr() string {
	mut str := if e.word_boundary { "(" } else { "{" }

	for i in 0 .. e.ar.len {
		if i > 0 { str += " " }
		str += e.ar[i].repr()
	}

	str += if e.word_boundary { ")" } else { "}" }
	return str
}

// ----------------------------------

pub struct DisjunctionPattern {
pub mut:
	ar []Pattern
	negative bool
}

pub fn (e DisjunctionPattern) input_len() ? int {
	if e.ar.len == 0 { return 0 }
	len := e.ar[0].input_len()?
	for pat in e.ar {
		if len != pat.input_len()? { return 0 }
	}
	return len
}

pub fn (e DisjunctionPattern) repr() string {
	mut str := "["
	if e.negative { str += "^ " }

	for i in 0 .. e.ar.len {
		if i > 0 { str += " " }
		str += e.ar[i].repr()
	}

	str += "]"
	return str
}

// ----------------------------------

pub struct MacroPattern {
pub:
	name string
pub mut:
	pat Pattern
}

pub fn (e MacroPattern) repr() string { return '${e.name}:${e.pat.repr()}' }

pub fn (e MacroPattern) input_len() ? int { return none }

// ----------------------------------

pub struct FindPattern {		// TODO Why is find: a pattern on its own? Everything else is a MacroPattern
pub:
	pat Pattern
	keepto bool
}

pub fn (e FindPattern) repr() string {
	alias := if e.keepto { "" } else { "alias "}
	return '{
grammar
	$alias<search> = {!${e.pat.repr()} .}*
	<anonymous> = {${e.pat.repr()}}
in
	alias find = {<search> <anonymous>}
end
}'
}

pub fn (e FindPattern) input_len() ? int { return none }

// ----------------------------------

interface GroupElem {
mut:
	ar []Pattern
}

pub type PatternElem = LiteralPattern | CharsetPattern | GroupPattern | DisjunctionPattern | NamePattern
		| EofPattern | MacroPattern | FindPattern | NonePattern


// TODO I'm wondering whether this is required with interfaces as well ?
pub fn (e PatternElem) repr() string {
	return match e {
		LiteralPattern { e.repr() }
		CharsetPattern { e.repr() }
		GroupPattern { e.repr() }
		DisjunctionPattern { e.repr() }
		NamePattern { e.repr() }
		EofPattern { e.repr() }
		MacroPattern { e.repr() }
		FindPattern { e.repr() }
		NonePattern { e.repr() }
	}
}

pub fn (e PatternElem) input_len() ? int {
	match e {
		LiteralPattern { return e.input_len() }
		CharsetPattern { return e.input_len() }
		GroupPattern { return e.input_len() }
		DisjunctionPattern { return e.input_len() }
		NamePattern { return e.input_len() }
		EofPattern { return e.input_len() }
		MacroPattern { return e.input_len() }
		FindPattern { return e.input_len() }
		NonePattern { return e.input_len() }
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

pub enum OperatorType {	// TODO to be removed by different group types
	sequence
	choice
	conjunction
}

// ----------------------------------

pub struct Pattern {
pub mut:
	predicate PredicateType = .na
	elem PatternElem = PatternElem(NonePattern{})
	min int = 1
	max int = 1							// -1 == '*' ==> 0, 1, or more
	operator OperatorType = .sequence	// the operator following the pattern
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

	if e.operator == .sequence { }
	if e.operator == .choice { str += " /" }
	if e.operator == .conjunction { str += " &" }

	return str
}

// ----------------------------------

// text A utility function. If the pattern contains a Literal, the return
// the text.
pub fn (p Pattern) text() ?string {
	if p.elem is LiteralPattern {
		return p.elem.text
	}
	panic("Pattern is not a LiteralPattern: ${p.elem.type_name()}")
}

pub fn (p Pattern) is_group() ? &GroupElem {
	if p.elem is GroupPattern { return &p.elem }
	if p.elem is DisjunctionPattern { return &p.elem }
	return error("Pattern is not one of the GroupPatterns: ${p.elem.type_name()}")
}

// at A utility function. If the pattern contains a Group, then return the
// pattern at the provided position.
pub fn (p Pattern) at(pos int) ?Pattern {
	if group := p.is_group() {
		if pos >= 0 && pos < group.ar.len {
			return group.ar[pos]
		}
		return error("GroupPattern: Index not found: index=${pos}; len=$group.ar.len")
	} else if p.elem is MacroPattern {
		return p.elem.pat.at(pos)
	}

	print_backtrace()
	return error("Pattern is not a GroupPattern: ${p.elem.type_name()}")
}

pub fn new_charset_pattern(str string) Pattern {
	return Pattern{ elem: CharsetPattern{ cs: new_charset_from_rpl(str) } }
}

pub fn new_sequence_pattern(word_boundary bool, elems []Pattern) Pattern {
	return Pattern{ elem: GroupPattern{ word_boundary: word_boundary, ar: elems } }
}

pub fn new_choice_pattern(negative bool, elems []Pattern) Pattern {
	return Pattern{ elem: DisjunctionPattern{ negative: negative, ar: elems } }
}

pub fn (p Pattern) input_len() ? int {
	if p.predicate != .na { return 0 }

	if l := p.elem.input_len() {
		if p.min == p.max {
			return l
		}
	}

	return none
}

pub fn (p Pattern) merge(x Pattern) Pattern {
	if p.min == 1 && p.max == 1 && p.predicate == .na && x.min == 1 && x.max == 1 && x.predicate == .na {
		return x
	}

	if p.min == 1 && p.max == 1 {
		if p.predicate == .na {
			return x
		} else if x.predicate == .na {
			return Pattern{ ...x, predicate: p.predicate }
		}
	}

	return Pattern{ ...p, elem: GroupPattern{ word_boundary: false, ar: [x] } }
}

[inline]
pub fn (p Pattern) is_standard() bool {
	return p.predicate == .na && p.min == 1 && p.max == 1
}

pub fn (p Pattern) get_charset() ? Charset {
	mut cs := p.get_charset_()?
	if p.predicate == .negative_look_ahead {
		cs = cs.complement()
	}
	return cs
}

pub fn (p Pattern) get_charset_() ? Charset {
	if p.elem is CharsetPattern {
		return p.elem.cs
	} else if p.elem is LiteralPattern {
		if p.elem.text.len == 1 {
			mut cs := new_charset()
			cs.set_char(p.elem.text[0])
			return cs
		}
	}
	return none
}

pub fn (mut p Pattern) copy_from(from Pattern) {
	p.predicate = from.predicate
	p.elem = from.elem
	p.min = from.min
	p.max = from.max
	p.operator = from.operator
}
