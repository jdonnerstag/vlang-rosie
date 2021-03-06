module v1

import rosie

const (
	bits_per_char = 8
	charset_size = ((rosie.uchar_max / bits_per_char) + 1) // == 32
	charset_inst_size = instsize(charset_size) // == 8
)

const (
	cs_alnum = new_charset_with_chars("0-9A-Za-z")
	cs_punct = new_charset_with_chars(r"!#$%&'()*+,\-./:;<=>?@[\]^_`{|} ~" + '"')
	cs_space = new_charset_with_chars("\t\n\f\r\v ")

	// See https://www.gnu.org/software/grep/manual/html_node/Character-Classes-and-Bracket-Expressions.html
	known_charsets = {
		"alnum": cs_alnum
		"alpha": new_charset_with_chars("A-Za-z")
		"blank": new_charset_with_chars(" \t")
		"cntrl": new_charset_with_chars("\000-\037\177")
		"digit": new_charset_with_chars("0-9")
		"graph": cs_alnum.copy().merge_or(cs_punct)
		"lower": new_charset_with_chars("a-z")
		"print": cs_alnum.copy().merge_or(cs_punct).merge_or(new_charset_with_chars(" "))
		"punct": cs_punct
		"space": cs_space
		"upper": new_charset_with_chars("A-Z")
		"xdigit": new_charset_with_chars("0-9A-Fa-f")
		"word": new_charset_with_chars("0-9A-Za-z_")
		"ascii": new_charset_with_chars("\000-\177")	 // 0 - 127
	}
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
	defval := if invers { u32(-1) } else { u32(0) }
	return Charset{ data: []Slot{ len: charset_inst_size, init: Slot(defval) } }
}

pub fn new_charset_with_byte(ch byte) Charset {
	mut cs := new_charset(false)
	cs.set_char(ch)
	return cs
}

pub fn new_charset_with_chars(str string) Charset {
	mut cs := new_charset(false)
	for i := 0; i < str.len; i++ {
		ch := str[i]
		if (i + 1) < str.len && str[i] != `\\` && str[i + 1] == `-` {
			for j := str[i]; j <= str[i + 2]; j++ { cs.set_char(j) }
			i += 2
		} else if (i + 1) < str.len && str[i] == `\\` {
			cs.set_char(str[i + 1])
			i += 1
		} else {
			cs.set_char(ch)
		}
	}
	return cs
}

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
	b := unsafe { ptr[0] }
	return (b & mask) != 0
}

fn (cs Charset) complement() Charset {
	mut cs1 := new_charset(false)
	for i, ch in cs.data {
		cs1.data[i] = Slot(~(u32(ch)))
	}
	return cs1
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

// TODO copy is a strange name for what it is doing
fn (cs Charset) copy() Charset {
	mut cs2 := new_charset(false)
	for i in 0 .. cs.data.len { cs2.data[i] = cs.data[i] }
	return cs2
}

fn (cs1 Charset) merge_and(cs2 Charset) Charset {
	mut cs := cs1.copy()
	for i in 0 .. cs1.data.len { cs.data[i] &= cs2.data[i] }
	return cs
}

fn (cs1 Charset) merge_or(cs2 Charset) Charset {
	mut cs := cs1.copy()
	for i in 0 .. cs1.data.len { cs.data[i] |= cs2.data[i] }
	return cs
}

fn (mut cs Charset) set_char(ch byte) Charset {
	mut ptr, mask := cs.byte_ptr(ch)
	unsafe  { ptr[0] |= mask }
	return cs
}

fn (cs Charset) count() (int, byte) {
	mut cnt := 0
	mut ch := byte(0)
	for i in 0 .. rosie.uchar_max {
		if cs.testchar(byte(i)) {
			cnt += 1
			ch = byte(i)
		}
	}
	return cnt, ch
}

fn (cs Charset) to_case_insensitive() Charset {
	mut cs1 := cs.copy()
	for i in 0 .. rosie.uchar_max {
		b := byte(i)
		if cs.testchar(b) {
			// TODO V's strconv lib has byte_to_lower(), but no byte_to_upper()
			str := b.ascii_str()
			cs1.set_char(str.to_lower()[0])
			cs1.set_char(str.to_upper()[0])
		}
	}
	return cs1
}

// testchar Assuming a charset starts at the program counter position 'pc',
// at the instructions provided, then test whether the char provided (byte)
// is contained in the charset.
[inline]
fn testchar(ch byte, byte_code []Slot, pc int) bool {
	return byte_code.to_charset(pc).testchar(ch)
}

fn (cs Charset) repr() string {
	mut rtn := "["
	mut open_idx := -1
	for i in 0 .. rosie.uchar_max {
		m := cs.testchar(byte(i))
		if m && open_idx < 0 {
			rtn += "(${i}"
			open_idx = i
		} else if !m && open_idx >= 0 {
			if open_idx == (i - 1) {
				rtn += ")"
			} else {
				rtn += "-${i-1})"
			}
			open_idx = -1
		}
	}

	if open_idx == (rosie.uchar_max - 1) {
		rtn += ")"
	} else if open_idx >= 0 {
		rtn += "-${rosie.uchar_max})"
	}

	rtn += "]"
	return rtn
}
