module runtime_v2

const (
	bits_per_char = 8
	charset_size = ((C.UCHAR_MAX / bits_per_char) + 1) // == 32
	charset_inst_size = instsize(charset_size) // == 8
)

pub const (
	cs_alnum = new_charset_from_rpl("0-9A-Za-z")
	cs_punct = new_charset_from_rpl(r"!#$%&'()*+,\-./:;<=>?@[\]^_`{|} ~" + '"')
	cs_space = new_charset_from_rpl("\t\n\f\r\v ")

	// See https://www.gnu.org/software/grep/manual/html_node/Character-Classes-and-Bracket-Expressions.html
	known_charsets = {
		"alnum": cs_alnum
		"alpha": new_charset_from_rpl("A-Za-z")
		"blank": new_charset_from_rpl(" \t")
		"cntrl": new_charset_from_rpl("\000-\037\177")
		"digit": new_charset_from_rpl("0-9")
		"graph": cs_alnum.clone().merge_or(cs_punct)
		"lower": new_charset_from_rpl("a-z")
		"print": cs_alnum.clone().merge_or(cs_punct).merge_or(new_charset_from_rpl(" "))
		"punct": cs_punct
		"space": cs_space
		"upper": new_charset_from_rpl("A-Z")
		"xdigit": new_charset_from_rpl("0-9A-Fa-f")
		"word": new_charset_from_rpl("0-9A-Za-z_")
		"ascii": new_charset_from_rpl("\000-\177")	 // 0 - 127
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

pub fn new_charset() Charset {
	return Charset{ data: []Slot{ len: charset_inst_size } }
}

fn (slot []Slot) to_charset(pc int) Charset {
	// Convert the array of int32 into an array of bytes (without copying the data)
	//ar := unsafe { byteptr(&instructions[pc]).vbytes(charset_size) }
	return Charset{ data: slot[pc .. pc + charset_inst_size ] }
}

pub fn (mut cs Charset) set_char(ch byte) Charset {
	x := int(ch)
	mask := 1 << (x & 0x1f)
	idx := x >> 5
	cs.data[idx] |= mask
	return cs
}

// TODO I think it is a bit awkward that V does not support new_charset().from_rpl()
//   with the reason that it doesn't know the charset must be 'mut'
pub fn new_charset_from_rpl(str string) Charset {
	mut cs := new_charset()
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

// cmp_char test whether the char provided (byte) is contained in the charset.
//[inline]
pub fn (cs Charset) cmp_char(ch byte) bool {
	x := int(ch)
	mask := 1 << (x & 0x1f)
	idx := x >> 5
	return (cs.data[idx] & mask) != 0
}

pub fn (cs Charset) complement() Charset {
	mut cs1 := new_charset()
	for i, ch in cs.data { cs1.data[i] = ~int(ch) }
	return cs1
}

[inline]
pub fn (cs1 Charset) is_equal(cs2 Charset) bool {
	return cs1.data == cs2.data
}

pub fn (cs1 Charset) is_disjoint(cs2 Charset) bool {
	for i in 0 .. cs1.data.len {
		if (cs1.data[i] & cs2.data[i]) != 0 {
			return false
		}
	}
  	return true
}

pub fn (cs Charset) clone() Charset {
	return Charset{ data: cs.data.clone() }
}

pub fn (cs1 Charset) merge_and(cs2 Charset) Charset {
	mut cs := cs1.clone()
	for i in 0 .. cs1.data.len { cs.data[i] &= cs2.data[i] }
	return cs
}

pub fn (cs1 Charset) merge_or(cs2 Charset) Charset {
	mut cs := cs1.clone()
	for i in 0 .. cs1.data.len { cs.data[i] |= cs2.data[i] }
	return cs
}

pub fn (cs Charset) count() (int, byte) {
	mut cnt := 0
	mut ch := byte(0)
	for i in 0 .. C.UCHAR_MAX {
		if cs.cmp_char(byte(i)) {
			cnt += 1
			ch = byte(i)
		}
	}
	return cnt, ch
}

pub fn (cs Charset) to_case_insensitive() Charset {
	mut cs1 := cs.clone()
	for i in 0 .. C.UCHAR_MAX {
		b := byte(i)
		if cs.cmp_char(b) {
			// TODO V's strconv lib has byte_to_lower(), but no byte_to_upper()
			str := b.ascii_str()
			cs1.set_char(str.to_lower()[0])
			cs1.set_char(str.to_upper()[0])
		}
	}
	return cs1
}

pub fn (cs Charset) repr() string {
	mut rtn := "["

	mut open_idx := -1
	for i in 0 .. C.UCHAR_MAX {
		m := cs.cmp_char(byte(i))
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

	if open_idx == (C.UCHAR_MAX - 1) {
		rtn += ")"
	} else if open_idx >= 0 {
		rtn += "-${C.UCHAR_MAX})"
	}

	rtn += "]"
	return rtn
}
