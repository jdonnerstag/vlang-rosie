module rosie

const ( 
	bits_per_char = 8
	charset_size = ((C.UCHAR_MAX / bits_per_char) + 1)	// == 32
	// size (in Instruction elements) for a ISet instruction
	charset_inst_size = instsize(charset_size) // == 8
)

// size (in elements) for an instruction plus extra l bytes
fn instsize(size int) int {
	return (size + int(sizeof(Instruction)) - 1) / int(sizeof(Instruction))
}

struct Charset {
  	cs []byte
}

fn new_charset() Charset {
	return Charset{ cs: []byte{ len: charset_size }}
}

// Charset is a bitset with 256 bits => 64 bytes => 4 x int32
fn (cs Charset) testchar(ch byte) bool {
	mask := int(1 << (ch & 7))
	b := int(cs.cs[int(ch) >> 3])
	return (b & mask) != 0
}

fn testchar(ch byte, instructions []Instruction, pc int) bool {
	if (pc + charset_inst_size) >= instructions.len {
		panic("Expected Charset but reached end-of-byte-code")
	}

	eprintln("charset_inst_size: $charset_inst_size, ${C.UCHAR_MAX}, $charset_size")

	ich := int(ch)
	mask := 1 << (ich & 0x7)
	idx := ich >> 3
	ar := (byteptr(&instructions) + (pc * 4)).vbytes(charset_size)
	for v in ar { eprint("${v.hex()}-") }
	eprintln("")
	b := ar[idx]
	rtn := (b & mask) != 0
	eprintln("ch: ${ich}, idx: $idx, b: ${b.hex()}, mask: ${mask.hex()}, rtn: $rtn")
	return rtn
}
