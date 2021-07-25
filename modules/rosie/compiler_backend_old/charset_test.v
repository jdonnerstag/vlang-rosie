module compiler_backend

import rosie.runtime as rt

fn test_fail() ? {
	cs := rt.new_charset(false)
	mut oc, b := charsettype(cs)
	assert oc == rt.Opcode.fail
	assert b == 0
}

fn test_any() ? {
	cs := rt.new_charset(true)
	mut oc, b := charsettype(cs)
	assert oc == rt.Opcode.any
	assert b == 0
}

fn test_single() ? {
	mut cs := rt.new_charset(false).set_char(`1`)
	mut oc, mut b := charsettype(cs)
	assert oc == rt.Opcode.char
	assert b == byte(`1`) // == 49

	cs = rt.new_charset(false).set_char(`a`)
	oc, b = charsettype(cs)
	assert oc == rt.Opcode.char
	assert b == byte(`a`)

	cs = rt.new_charset(false).set_char(13)
	oc, b = charsettype(cs)
	assert oc == rt.Opcode.char
	assert b == byte(13)

	cs = rt.new_charset(false).set_char(128)
	oc, b = charsettype(cs)
	assert oc == rt.Opcode.char
	assert b == byte(128)

	cs = rt.new_charset(false).set_char(255)
	oc, b = charsettype(cs)
	assert oc == rt.Opcode.char
	assert b == byte(255)

	cs = rt.new_charset(false).set_char(0)
	oc, b = charsettype(cs)
	assert oc == rt.Opcode.char
	assert b == byte(0)
}

fn test_set() ? {
	cs := rt.new_charset(false).set_char(`1`).set_char(`2`)
	mut oc, b := charsettype(cs)
	assert oc == rt.Opcode.set
	assert b == 0
}