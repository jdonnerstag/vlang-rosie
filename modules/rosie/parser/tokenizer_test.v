module parser


fn test_simple() ? {
	mut tok := new_tokenizer(r'aaa', 0)?

	assert tok.next_token()? == .text
	assert tok.get_text() == "aaa"

	if _ := tok.next_token() { assert false }
}

fn test_tokenizer() ? {
	mut tok := new_tokenizer(r'local pat={"a\"bc" .}', 0)?

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
	mut tok := new_tokenizer('-- comment\n--\n', 0)?

	assert tok.next_token()? == .comment
	assert tok.get_text() == "-- comment"

	assert tok.next_token()? == .comment
	assert tok.get_text() == "--"

	if _ := tok.next_token() { assert false }
}

fn test_escaped_quoted() ? {
	data := r'"\\\"" / "\\\"\\\"" / {["]["]}'
	assert data[0] == `"`
	assert data[1] == `\\`
	assert data[2] == `\\`
	assert data[3] == `\\`
	assert data[4] == `"`

	mut tok := new_tokenizer(data, 99)?

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
