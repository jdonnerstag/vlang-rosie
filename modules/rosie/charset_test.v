module rosie

fn test_knowns() ? {
	assert bits_per_char == 8
	assert uchar_max == 255
	assert charset_size == 32
	assert int(sizeof(int)) == 4
	assert charset_inst_size == 8	// TODO If that fails, then a lot more will be broken
	assert is_print(`a`) == true
	assert is_print(`\r`) == false
	assert cs_alnum.repr() == "[(48-57)(65-90)(97-122)]"
	assert cs_alnum.repr_str() == "[0-9A-Za-z]"
	assert cs_punct.repr() == "[(32-47)(58-64)(91)(93-96)(123-126)]"
}

fn test_dyn_to_fixed() ? {
	mut ar := []int{}
	for i in 0 .. 100 { ar << i }
	cs := to_charset(unsafe{ &ar[10] })
	assert cs.data == [u32(10), 11, 12, 13, 14, 15, 16, 17]!		// "!" creates a fixed size array
}

fn test_new_charset() ? {
	cs := new_charset()
	assert cs.repr() == "[]"
}

fn test_set_char() ? {
	mut cs := new_charset()
	cs.set_char(`9`)
	assert cs.repr_str() == "[9]"
	cs.set_char(`7`)
	cs.set_char(`8`)
	assert cs.repr_str() == "[7-9]"
	cs.set_char(`a`)
	assert cs.repr_str() == "[7-9a]"
}

fn test_clone() ? {
	mut cs := new_charset()
	cs.set_char(`9`)
	assert cs.repr_str() == "[9]"

	cs2 := cs.clone()
	assert cs2.repr_str() == "[9]"
	assert cs.is_equal(cs2)
}

fn test_merge_or() ? {
	mut cs1 := new_charset()
	cs1.set_char(`a`)

	mut cs2 := new_charset()
	cs2.set_char(`c`)

	assert cs1.merge_or(cs2).repr_str() == "[ac]"
}

fn test_merge_and() ? {
	mut cs1 := new_charset()
	cs1.set_char(`a`)
	cs1.set_char(`b`)
	cs1.set_char(`c`)

	mut cs2 := new_charset()
	cs2.set_char(`b`)

	assert cs1.merge_and(cs2).repr_str() == "[b]"
}

fn test_complement() ? {
	mut cs1 := new_charset()
	cs1.set_char(`a`)
	assert cs1.complement().repr() == "[(0-96)(98-255)]"
	assert cs1.complement().complement().repr_str() == "[a]"
}

fn test_hex() ? {
	mut cs1 := new_charset_from_rpl(r"\xC0-\xDF")
	assert cs1.repr() == "[(192-223)]"
}

fn test_escape() ? {
	mut cs1 := new_charset_from_rpl(r"\\")
	assert cs1.repr() == "[(92)]"

	cs1 = new_charset_from_rpl(r" \t\r")
	assert cs1.repr() == "[(9)(13)(32)]"
}
