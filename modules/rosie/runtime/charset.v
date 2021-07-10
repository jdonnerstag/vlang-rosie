module runtime

const (
	bits_per_char = 8
	charset_size = ((C.UCHAR_MAX / bits_per_char) + 1) // == 32
	charset_inst_size = instsize(charset_size) // == 8
)

// instsize Every VM byte code instruction ist 32 bit. Determine how many
// slots are needed for a charset.
fn instsize(size int) int {
	return (size + int(sizeof(Instruction)) - 1) / int(sizeof(Instruction))
}

// testchar Assuming a charset starts at the program counter position 'pc',
// at the instructions provided, then test whether the char provided (byte)
// is contained in the charset.
fn testchar(ch byte, instructions []Instruction, pc int) bool {
	if (pc + charset_inst_size) >= instructions.len {
		panic("Expected Charset but reached end-of-byte-code")
	}

	// Convert the array of int32 into an array of bytes (without copying the data)
	ar := unsafe { byteptr(&instructions[pc]).vbytes(charset_size) }

	mask := 1 << (ch & 0x7)
	idx := ch >> 3
	return (ar[idx] & mask) != 0
}
