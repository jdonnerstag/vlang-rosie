module parser

import rosie.runtime as rt

struct LiteralExpressionType {
pub mut:
	text string
}

struct CharsetExpressionType {
pub mut:
	charset rt.Charset
}

// "."
struct AnyExpressionType {
}

struct ChoiceExpressionType {
pub mut:
	p Expression
	q Expression
}

struct SequenceExpressionType {
pub mut:
	p Expression
	q Expression
}

struct ConjunctionExpressionType {
pub mut:
	p Expression
	q Expression
}

struct LookAheadExpressionType {
pub mut:
	p Expression
}

struct NegativeLookAheadExpressionType {
pub mut:
	p Expression
}

struct LookBehindExpressionType {
pub mut:
	p Expression
}

struct NegativLookBehindExpressionType {
pub mut:
	p Expression
}

struct TokenizedExpressionType {
pub mut:
	p Expression
}

type ExpressionType = LiteralExpressionType | CharsetExpressionType | AnyExpressionType | ChoiceExpressionType | SequenceExpressionType |
		ConjunctionExpressionType | LookAheadExpressionType | NegativeLookAheadExpressionType | LookBehindExpressionType |
		NegativLookBehindExpressionType | TokenizedExpressionType

struct Expression {
pub mut:
	expr ExpressionType

	min int
	max int			// -1 == '*' == 0, 1, or more
}
