module engine


fn test_engine() ? {
	mut rosie := engine.new_engine(debug: 0)?
	rosie.prepare(rpl: '{[a] [b]}')?
	assert rosie.binding("*")?.pattern.repr() == '{"a" "b"}'
	assert rosie.binding("*")?.pattern.input_len()? == 2
}

fn test_match_input() ? {
	mut rosie := engine.new_engine(debug: 0)?
	rosie.prepare(rpl: '"a"*', debug: 0, unit_test: false)?

	mut line := ""
	assert rosie.match_input(line, debug: 0)? == true
	assert rosie.get_match()? == line
	assert rosie.matcher.pos == line.len

	line = "a"
	assert rosie.match_input(line, debug: 0)? == true
	assert rosie.get_match()? == line
	assert rosie.matcher.pos == line.len

	line = "aaa"
	assert rosie.match_input(line, debug: 0)? == true
	assert rosie.get_match()? == line
	assert rosie.matcher.pos == line.len

	line = "aaab"
	assert rosie.match_input(line, debug: 0)? == true
	assert rosie.get_match()? == "aaa"
	assert rosie.matcher.pos == 3

	line = "b"
	assert rosie.match_input(line, debug: 0)? == true
	assert rosie.get_match()? == ""
	assert rosie.matcher.pos == 0

	line = "baaa"
	assert rosie.match_input(line, debug: 0)? == true
	assert rosie.get_match()? == ""
	assert rosie.matcher.pos == 0
}

fn test_match() ? {
	mut rosie := engine.new_engine(debug: 0)?
	assert rosie.match_("aaa", rpl: '"a"*')? == true

	// The most simple use case, even without
	assert match_("bbb", '"b"+')? == true		// TODO a little inconsistent. rosie.match_ vs match_ arguments
}
