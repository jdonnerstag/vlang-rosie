module parser

fn test_literal() ? {
	str := LiteralExpressionType{ text: "abc" }
	expr := Expression{ expr: str, min: 1, max: 1 }
}

fn test_sequence() ? {
	str1 := LiteralExpressionType{ text: "abc" }
	expr1 := Expression{ expr: str1, min: 1, max: 1 }

	str2 := LiteralExpressionType{ text: "123" }
	expr2 := Expression{ expr: str2, min: 1, max: 1 }

	str3 := SequenceExpressionType{ p: expr1, q: expr2 }
	expr3 := Expression{ expr: str3, min: 1, max: 1 }
}
