module rosie

fn test_new_array_tree() ? {
	ar := new_array_tree(10)
	assert ar.data.len == 0
	assert ar.len(0)? == 0
	if _ := ar.len(1) { assert false }
}

fn test_add() ? {
	mut ar := new_array_tree(10)

	ar.add(Pattern{ elem: LiteralPattern{ text: "111" }})
	assert ar.data.len == 1
	assert ar.len(0)? == 1
	if _ := ar.len(1) { assert false }
	assert (ar.data[0].elem.elem as LiteralPattern).text == "111"

	ar.add(Pattern{ elem: LiteralPattern{ text: "222" }})
	assert ar.data.len == 2
	assert ar.len(0)? == 2
	if _ := ar.len(1) { assert false }
	assert (ar.data[0].elem.elem as LiteralPattern).text == "111"
	assert (ar.data[1].elem.elem as LiteralPattern).text == "222"
}

fn test_incr_level() ? {
	mut ar := new_array_tree(10)

	ar.add(Pattern{ elem: LiteralPattern{ text: "1-1" }})

	ar.incr_level()
	assert ar.data.len == 2
	assert ar.len(0)? == 2
	ar.add(Pattern{ elem: LiteralPattern{ text: "2-1" }})
	assert ar.data.len == 3
	assert ar.len(0)? == 2
	assert ar.len(1)? == 1
	if _ := ar.len(2) { assert false }

	ar.add(Pattern{ elem: LiteralPattern{ text: "2-2" }})
	assert ar.data.len == 4
	assert ar.len(0)? == 2
	assert ar.len(1)? == 2
	if _ := ar.len(2) { assert false }

	ar.incr_level()
	assert ar.data.len == 5
	assert ar.len(0)? == 2
	assert ar.len(1)? == 3
	ar.add(Pattern{ elem: LiteralPattern{ text: "3-1" }})
	assert ar.data.len == 6
	assert ar.len(0)? == 2
	assert ar.len(1)? == 3
	assert ar.len(2)? == 1
	if _ := ar.len(3) { assert false }

	ar.decr_level()
	assert ar.data.len == 6
	ar.add(Pattern{ elem: LiteralPattern{ text: "2-3" }})
	assert ar.data.len == 7
	assert ar.len(0)? == 2
	assert ar.len(1)? == 4
	assert ar.len(2)? == 1
	if _ := ar.len(3) { assert false }

	ar.decr_level()
	// ar.decr_level()	// Vlang does not support catching panic

	assert ar.repr() == '"1-1" ("2-1" "2-2" ("3-1") "2-3")'
}
/* */
