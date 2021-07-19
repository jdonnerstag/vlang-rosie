module parser

import rosie.runtime as rt

enum PredicateType {
	na
	look_ahead
	negative_look_ahead
	look_behind
	negative_look_behind
}

enum PatternType {
	na
	literal
	charset
	any
}

enum OperatorType {
	na
	sequence
	choice
	conjunction
}

// TODO we may use sumtypes later on to make it nicer
struct Expression {
pub mut:
	predicate PredicateType = .na
	pattern PatternType = .na
	operator OperatorType = .na

	text string
	charset rt.Charset

	subs []int		// Sub-expressions (by their index in the master list)

	min int = 1
	max int = 1		// -1 == '*' == 0, 1, or more

	word_boundary bool = true
}

pub fn (e Expression) str() string {
	return "Expression: tok=(.$e.predicate, .$e.pattern, .$e.operator), '$e.text', {$e.min, $e.max}, words=$e.word_boundary, subs=$e.subs"
}

pub fn (e Expression) print(p Parser, level int) {
	str := e.str()
	eprintln("${' '.repeat(level * 2)}$str")
	for i in e.subs {
		p.expressions[i].print(p, level + 1)
	}
}
