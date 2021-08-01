module runtime

import os

fn test_magic_number() ? {
	assert file_magic_number.starts_with("RPLX")
}

fn test_endian() ? {
	// Little endian
	assert unsafe { (*(&int(file_magic_number.str))).hex() } == 0x58_4C_50_52.hex()
}

fn text_instruction_struct() ? {
	mut x := Slot(0)
	assert int(x.opcode()) == 0
	assert x.aux() == 0
	assert x.ichar() == 0

	x = Slot(0x0123_4567)
	assert int(x.opcode()) == 0x01
	assert x.aux() == 0x0023_4567
	assert x.ichar() == 0x01
}

fn test_encode_int() ? {
	rplx := Rplx{}
	assert rplx.encode_int(0) == [byte(0), 0, 0, 0]
	assert rplx.encode_int(0x1234_5678).hex() == [byte(0x78), 0x56, 0x34, 0x12].hex()
}

fn test_buffer() ? {
	mut buf := Buffer{ data: [] }
	if _ := buf.get(1) { assert false }

	buf = Buffer{ data: "1234567890".bytes() }
	assert buf.get(4)? == "1234".bytes()
	assert buf.get(4)? == "5678".bytes()
	assert buf.get(2)? == "90".bytes()
	if _ := buf.get(2) { assert false }
}

fn test_buffer_read_int() ? {
	mut buf := Buffer{ data: [byte(1), 2, 3, 4, 5, 6, 7, 8, 9, 0] }
	assert buf.read_int()?.hex() == 0x04030201.hex()
	assert buf.read_int()?.hex() == 0x08070605.hex()
	if _ := buf.read_int() { assert false }
}

fn test_net_ipv4_rplx() ? {
	fname := os.dir(@FILE) + "/test_data/net.ipv4.rplx"
	rplx := load_rplx(fname, 4)?
}