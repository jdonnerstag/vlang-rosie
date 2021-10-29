module runtime_v1

// Buffer Used for reading the RPLX file, which contains the compiled version of
// the RPL file. The virtual machine RPL runtime, executes these instructions
// when matching input data.
struct Buffer {
pub:
	data []byte
pub mut:
	pos int
}

fn (buf Buffer) eof() bool { return buf.pos >= buf.data.len }

// leftover Number of bytes remaining in input
fn (buf Buffer) leftover() int {
	return buf.data.len - buf.pos
}

// get Consume n-bytes from the input stream
fn (mut buf Buffer) get(len int) ?[]byte {
	stop := buf.pos + len
	if stop > buf.data.len {
		return error("Not enough data in buffer: pos=$buf.pos, requested=$len, len=$buf.data.len")
	}
	rtn := buf.data[buf.pos .. stop]
	buf.pos = stop
	return rtn
}

// get_byte Consume 1-byte from the input stream
fn (mut buf Buffer) get_byte() ?byte {
	if buf.pos < buf.data.len {
		b := buf.data[buf.pos]
		buf.pos ++
		return b
	}
	return error("Not enough data in buffer: pos=$buf.pos, requested=1, len=$buf.data.len")
}

// peek_byte Consume 1-byte from the input stream
[inline]
fn (buf Buffer) peek_byte() byte {
	return buf.data[buf.pos]
}

// read_int Consume a 32bit integer from the buffer
fn (mut buf Buffer) read_int() ?int {
	// TODO Reading ints could be optimized if the data would be aligned to 32bit boundary
	// How often does it happen that rplx files are copied from one server to another
	// with different endians? Very rarely I assume. Put the endian in the meta-data and compare
	// upon reading the meta-data. Ask the user to recompile the rplx file.
	data := buf.get(4)?
	if little_endian {
		return int(data[0]) | (int(data[1]) << 8) | (int(data[2]) << 16) | (int(data[3]) << 24)
	} else {
		return int(data[3]) | (int(data[2]) << 8) | (int(data[1]) << 16) | (int(data[0]) << 24)
	}
}

// next_section Sections are separated by "\n" in the rplx file
fn (mut buf Buffer) next_section(debug int) ? {
	if debug > 0 { eprintln("pos: $buf.pos; next section") }

	dummy := buf.get(1)?
	if dummy[0] != `\n` { return error("Expected newline at pos: $buf.pos, found: $dummy") }

	// TODO We could speed up reading the file, if the file content would be 32-bit
	// aligned. The CPU wouldn't need to do any memcpy.
	//buf.pos = (buf.pos + 4) & 0xFFFF_FFFFC	 // 32 bit / 4 byte boundary aligned
}
