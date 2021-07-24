module runtime

const (
	bits_per_char = 8
	charset_size = ((C.UCHAR_MAX / bits_per_char) + 1) // == 32
	charset_inst_size = instsize(charset_size) // == 8
)

// instsize Every VM byte code instruction ist 32 bit. Determine how many
// slots are needed for a charset.
fn instsize(size int) int {
	return (size + int(sizeof(Slot)) - 1) / int(sizeof(Slot))
}

// Charset In our use case the charset data will always be part of the
// byte code instructions.
pub struct Charset {
pub mut:
	data []Slot
}

pub fn new_charset(invers bool) Charset {
	defval := if invers { -1 } else { 0 }
	return Charset{ data: []Slot{ len: charset_inst_size, init: Slot(defval) } }
}

pub fn new_charset_with_byte(ch byte) Charset {
	mut cs := new_charset(false)
	cs.set_char(ch)
	return cs
}

[inline]
fn (slot []Slot) to_charset(pc int) Charset {
	// Convert the array of int32 into an array of bytes (without copying the data)
	//ar := unsafe { byteptr(&instructions[pc]).vbytes(charset_size) }
	return Charset{ data: slot[pc .. pc + charset_inst_size ] }
}

[inline]
fn (cs Charset) byte_ptr(ch byte) (byteptr, byte) {
	mask := 1 << (ch & 0x7)
	idx := ch >> 3
	ptr := unsafe { byteptr(cs.data.data) + idx }
	return ptr, byte(mask)
}

// testchar test whether the char provided (byte) is contained in the charset.
[inline]
fn (cs Charset) testchar(ch byte) bool {
	ptr, mask := cs.byte_ptr(ch)
	return (*ptr & mask) != 0
}

fn (mut cs Charset) complement() Charset {
	for i, ch in cs.data { cs.data[i] = Slot(~(int(ch))) }
	return cs
}

fn (cs1 Charset) is_equal(cs2 Charset) bool {
	for i in 0 .. cs1.data.len {
		if cs1.data[i] != cs2.data[i] {
			return false
		}
	}
  	return true
}

fn (cs1 Charset) is_disjoint(cs2 Charset) bool {
	for i in 0 .. cs1.data.len {
		if (cs1.data[i] & cs2.data[i]) != 0 {
			return false
		}
	}
  	return true
}

fn (mut cs1 Charset) copy(cs2 Charset) {
	for i in 0 .. cs1.data.len { cs1.data[i] = cs2.data[i] }
}

fn (mut cs1 Charset) merge_and(cs2 Charset) {
	for i in 0 .. cs1.data.len { cs1.data[i] &= cs2.data[i] }
}

fn (mut cs1 Charset) merge_or(cs2 Charset) {
	for i in 0 .. cs1.data.len { cs1.data[i] |= cs2.data[i] }
}

fn (mut cs Charset) set_char(ch byte) Charset {
	mut ptr, mask := cs.byte_ptr(ch)
	unsafe  { ptr[0] |= mask }
	return cs
}

// testchar Assuming a charset starts at the program counter position 'pc',
// at the instructions provided, then test whether the char provided (byte)
// is contained in the charset.
[inline]
fn testchar(ch byte, byte_code []Slot, pc int) bool {
	return byte_code.to_charset(pc).testchar(ch)
}

fn (cs Charset) str() string {
	mut rtn := "["
	mut open_idx := -1
	for i in 0 .. C.UCHAR_MAX {
		m := cs.testchar(byte(i))
		if m && open_idx < 0 {
			rtn += "(${i + 1}"
			open_idx = i
		} else if !m && open_idx >= 0 {
			if open_idx == (i - 1) {
				rtn += ")"
			} else {
				rtn += "-${i})"
			}
			open_idx = -1
		}
	}

	if open_idx == (C.UCHAR_MAX - 1) {
		rtn += ")"
	} else if open_idx >= 0 {
		rtn += "-${C.UCHAR_MAX})"
	}

	return rtn + "]"
}
