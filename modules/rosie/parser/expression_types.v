module parser

import rosie.runtime as rt

enum ExpressionType {
	literal
	charset
	any
	choice
	sequence
	conjunction
	look_ahead
	negative_look_ahead
	look_behind
	negative_look_behind
}

struct Expression {
pub mut:
	etype ExpressionType
	text string
	charset rt.Charset

	subs []int		// Sub-expressions

	min int = 1
	max int = 1		// -1 == '*' == 0, 1, or more

	word_boundary bool = true
}

pub fn (e Expression) str() string {
	return "Expression: tok=$e.etype, '$e.text', {$e.min, $e.max}, b=$e.word_boundary, subs=$e.subs"
}

pub fn (e Expression) print(p Parser, level int) {
	eprintln("${' '.repeat(level * 2)}Expression: tok=$e.etype, '$e.text', {$e.min, $e.max}, b=$e.word_boundary, subs=$e.subs")
	for i in e.subs {
		p.expressions[i].print(p, level + 1)
	}
}
