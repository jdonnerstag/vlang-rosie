module rosie

import strconv

#include <ctype.h>

fn C.isprint(int) int

pub fn is_print(ch byte) bool {
	return C.isprint(int(ch)) != 0
}

const (
	// TODO There is a bug in V: consts depending on other consts may be initialised in wrong order, yielding wrong values !!!
	bits_per_char = 8
	charset_size = 32 // ((uchar_max / bits_per_char) + 1) // == 32
	charset_inst_size = 8 // instsize(charset_size) // == 8
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
	return (size + int(sizeof(int)) - 1) / int(sizeof(int))
}

// Charset In our use case the charset data will always be part of the
// byte code instructions.
pub struct Charset {
pub mut:
	data [8 /* charset_inst_size */ ]u32   // TODO Even charset_inst_size is a const, it cannot be used. In V consts are not yet compile-time constants.
}

pub fn new_charset() Charset {
	return Charset{}
}

pub fn (cs Charset) clone() Charset {
	// return Charset{ data: cs.data }  // TODO Not working as expected
	mut cs1 := Charset{}
	unsafe { vmemcpy(&cs1.data, &cs.data, 4 * 8) }
	return cs1
}

pub fn to_charset(src voidptr) Charset {
	// Convert the array of int32 into an array of bytes (without copying the data)
	//ar := unsafe { byteptr(&instructions[pc]).vbytes(charset_size) }
	mut cs := Charset{}
	unsafe { vmemcpy(&cs.data, src, 4 * 8) }
	return cs
}

pub fn (mut cs Charset) set_char(ch byte) {
	x := u32(ch)
	mask := u32(1) << (x & 0x1f)
	idx := x >> 5
	cs.data[idx] |= mask
}

// TODO I think it is a bit awkward that V does not support new_charset().from_rpl()
//   with the reason that it doesn't know the charset must be 'mut'
pub fn new_charset_from_rpl(str string) Charset {
	mut cs := new_charset()
	cs.from_rpl(str)
	return cs
}

pub fn (mut cs Charset) from_rpl(str string) {
	ar := cs.unescape_str(str)
	//eprintln("from_rpl: str:'$str' - bytes: $ar")
	for i := 0; i < ar.len; i++ {
		ch := ar[i]
		if (i + 1) < ar.len && ch != `\\` && ar[i + 1] == `-` {
			for j := ch; j <= ar[i + 2]; j++ {
				cs.set_char(j)
			}
			i += 2
		} else if (i + 1) < ar.len && ch == `\\` {
			cs.set_char(ar[i + 1])
		} else {
			cs.set_char(ch)
		}
	}
}

pub fn (mut cs Charset) unescape_str(str string) []byte {
	mut ar := []byte{ cap: str.len }
	mut diff := 1
	mut b := byte(0)
	for i := 0; i < str.len; i += diff {
		b, diff = cs.byte_from_str(str, i)
		ar << b
	}
	return ar
}

pub fn (cs Charset) byte_from_str(str string, i int) (byte, int) {
	if (i + 3) < str.len && str[i] == `\\` && str[i + 1] == `x` {
		return cs.byte_from_hex(str, i)
	} else {
		return str[i], 1
	}
}

pub fn (cs Charset) byte_from_hex(str string, i int) (byte, int) {
	if str[i + 2].is_hex_digit() && str[i + 3].is_hex_digit() {
		x := strconv.parse_int(str[i + 2 .. i + 4], 16, 8) or {
			panic("Invalid hex escape sequence in: '$str': $err.msg")
		}
		return byte(x), 4
	}
	panic("Invalid hex escape sequence: '$str'")
}

// cmp_char test whether the char provided (byte) is contained in the charset.
pub fn (cs Charset) contains(ch byte) bool {
	mask := u32(1) << (u32(ch) & 0x1f)
	idx := u32(ch) >> 5
	return (cs.data[idx] & mask) != 0
}

pub fn (cs Charset) complement() Charset {
	mut cs1 := cs.clone()
	for i in 0 .. charset_inst_size {
		cs1.data[i] = ~cs.data[i]
	}
	return cs1
}

[inline]
pub fn (cs1 Charset) is_equal(cs2 Charset) bool {
	return cs1.data == cs2.data
}

pub fn (cs1 Charset) is_disjoint(cs2 Charset) bool {
	for i in 0 .. charset_inst_size {
		if (cs1.data[i] & cs2.data[i]) != 0 {
			return false
		}
	}
	return true
}

pub fn (cs Charset) merge_and(cs2 Charset) Charset {
	mut cs1 := cs.clone()
	for i in 0 .. charset_inst_size {
		cs1.data[i] &= cs2.data[i]
	}
	return cs1
}

pub fn (cs Charset) merge_or(cs2 Charset) Charset {
	mut cs1 := cs.clone()
	for i in 0 .. charset_inst_size {
		cs1.data[i] |= cs2.data[i]
	}
	return cs1
}

pub fn (cs Charset) count() (int, byte) {
	mut cnt := 0
	mut ch := byte(0)
	for i in 0 .. uchar_max {
		if cs.contains(byte(i)) {
			cnt += 1
			ch = byte(i)
		}
	}
	return cnt, ch
}

pub fn (cs Charset) to_case_insensitive() Charset {
	mut cs1 := cs.clone()
	for i in 0 .. uchar_max {
		b := byte(i)
		if cs.contains(b) {
			// TODO V's strconv lib has byte_to_lower(), but no byte_to_upper()
			// and the below implementation is very slow
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
	for i in 0 .. uchar_max {
		m := cs.contains(byte(i))
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

pub fn (cs Charset) repr_str() string {
	mut rtn := "["
	mut open_idx := -1
	for i in 0 .. uchar_max {
		m := cs.contains(byte(i))
		if m && open_idx < 0 {
			rtn += if is_print(i) { byte(i).ascii_str() } else { "($i)"}
			open_idx = i
		} else if !m && open_idx >= 0 {
			if open_idx != (i - 1) {
				rtn += if is_print(i) { "-${byte(i-1).ascii_str()}" } else { "($i)" }
			}
			open_idx = -1
		}
	}

	if open_idx >= 0 {
		rtn += "-(${uchar_max})"
	}

	rtn += "]"
	return rtn
}
