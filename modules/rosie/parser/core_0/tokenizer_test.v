module core_0


fn test_simple() ? {
	mut tok := new_tokenizer(0)
    tok.init(r'aaa')?

	assert tok.next_token()? == .text
	assert tok.get_text() == "aaa"

	if _ := tok.next_token() { assert false }
}

fn test_tokenizer() ? {
	mut tok := new_tokenizer(0)
    tok.init(r'local pat={"a\"bc" .}')?

	assert tok.next_token()? == .text
	assert tok.get_text() == "local"

	assert tok.next_token()? == .text
	assert tok.get_text() == "pat"

	assert tok.next_token()? == .equal
	assert tok.next_token()? == .open_brace
	assert tok.next_token()? == .quoted_text
	assert tok.get_quoted_text() == 'a"bc'
	assert tok.next_token()? == .text
	assert tok.get_text() == "."
	assert tok.next_token()? == .close_brace
	if _ := tok.next_token() { assert false }
}

fn test_comment() ? {
	mut tok := new_tokenizer(0)
    tok.init('-- comment\n--\n')?

	assert tok.next_token()? == .comment
	assert tok.get_text() == "-- comment"

	assert tok.next_token()? == .comment
	assert tok.get_text() == "--"

	if _ := tok.next_token() { assert false }
}

fn test_alias() ? {
	mut tok := new_tokenizer(0)
    tok.init('-- comment\nalias quote = "\\\""')?

	assert tok.next_token()? == .comment
	assert tok.get_text() == "-- comment"

	assert tok.next_token()? == .text
	assert tok.get_text() == "alias"

	assert tok.next_token()? == .text
	assert tok.get_text() == "quote"

	assert tok.next_token()? == .equal
	assert tok.get_text() == "="

	assert tok.next_token()? == .quoted_text
	assert tok.get_quoted_text() == '"'

	if _ := tok.next_token() { assert false }
}

fn test_escaped_quoted() ? {
	data := r'"\\\"" / "\\\"\\\"" / {["]["]}'
	assert data[0] == `"`
	assert data[1] == `\\`
	assert data[2] == `\\`
	assert data[3] == `\\`
	assert data[4] == `"`

	mut tok := new_tokenizer(0)
    tok.init(data)?

	assert tok.next_token()? == .quoted_text
	assert tok.peek_text() == r'"\\\""'
	assert tok.get_quoted_text() == r'\"'

	assert tok.next_token()? == .choice

	assert tok.next_token()? == .quoted_text
	assert tok.peek_text() == r'"\\\"\\\""'
	assert tok.get_quoted_text() == r'\"\"'

	assert tok.next_token()? == .choice

	assert tok.next_token()? == .open_brace
	assert tok.next_token()? == .charset
	assert tok.peek_text() == r'["]'
	assert tok.get_quoted_text() == r'"'
	assert tok.next_token()? == .charset
	assert tok.peek_text() == r'["]'
	assert tok.get_quoted_text() == r'"'
	assert tok.next_token()? == .close_brace
}

fn test_charset() ? {
	mut tok := new_tokenizer(0)
    tok.init('[:digit:]')?
	assert tok.next_token()? == .charset
	assert tok.peek_text() == r'[:digit:]'
	assert tok.get_quoted_text() == r':digit:'

	tok.init('[:^digit:]')?
	assert tok.next_token()? == .charset
	assert tok.peek_text() == r'[:^digit:]'
	assert tok.get_quoted_text() == r':^digit:'

	tok.init('[a-z]')?
	assert tok.next_token()? == .charset
	assert tok.peek_text() == r'[a-z]'
	assert tok.get_quoted_text() == r'a-z'

	tok.init('[^a-f]')?
	assert tok.next_token()? == .charset
	assert tok.peek_text() == r'[^a-f]'
	assert tok.get_quoted_text() == r'^a-f'

	tok.init('[abcdef]')?
	assert tok.next_token()? == .charset
	assert tok.peek_text() == r'[abcdef]'
	assert tok.get_quoted_text() == r'abcdef'

	tok.init('[^abcdef]')?
	assert tok.next_token()? == .charset
	assert tok.peek_text() == r'[^abcdef]'
	assert tok.get_quoted_text() == r'^abcdef'

	tok.init('[[:digit:][a-f]]')?
	assert tok.next_token()? == .open_bracket
	assert tok.next_token()? == .charset
	assert tok.get_quoted_text() == r':digit:'
	assert tok.next_token()? == .charset
	assert tok.get_quoted_text() == r'a-f'
	assert tok.next_token()? == .close_bracket

	tok.init('[[:digit:] cs2] alias')?
	assert tok.next_token()? == .open_bracket
	assert tok.next_token()? == .charset
	assert tok.get_quoted_text() == r':digit:'
	assert tok.next_token()? == .text
	assert tok.get_text() == r'cs2'
	assert tok.next_token()? == .close_bracket
	assert tok.next_token()? == .text
	assert tok.get_text() == r'alias'

	tok.init(r'[_\-]')?
	assert tok.next_token()? == .charset

	tok.init(r'[^[:digit:][a-f]]')?
	assert tok.next_token()? == .open_bracket
	assert tok.next_token()? == .text
	assert tok.next_token()? == .charset
	assert tok.next_token()? == .charset
	assert tok.next_token()? == .close_bracket
}

fn test_issue_1() ? {
	mut tok := new_tokenizer(0)
    tok.init('>{{"."? [[:space:] $]} / [[:punct:] & !"."]}')?
	assert tok.next_token()? == .greater
	assert tok.next_token()? == .open_brace
	assert tok.next_token()? == .open_brace
	assert tok.next_token()? == .quoted_text
	assert tok.next_token()? == .question_mark
	assert tok.next_token()? == .open_bracket
	assert tok.next_token()? == .charset
	assert tok.next_token()? == .text
	assert tok.next_token()? == .close_bracket
	assert tok.next_token()? == .close_brace
	assert tok.next_token()? == .choice
	assert tok.next_token()? == .open_bracket
	assert tok.next_token()? == .charset
	assert tok.next_token()? == .ampersand
	assert tok.next_token()? == .not
	assert tok.next_token()? == .quoted_text
	assert tok.next_token()? == .close_bracket
	assert tok.next_token()? == .close_brace
}