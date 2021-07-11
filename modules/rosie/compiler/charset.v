module compiler

import rosie.runtime as rt

// Check whether a charset is empty (returns IFail), singleton (IChar),
// full (IAny), or none of those (ISet). When singleton, '*c' returns
// which character it is. (When generic set, the set was the input,
// so there is no need to return it.)
fn charsettype(cs rt.Charset) (rt.Opcode, byte) {
    mut count := 0
    mut candidate := -1  // candidate position for the singleton char
    for i in 0 .. cs.data.len {  // for each byte
        b := cs.data[i]
        if b == 0 {  // is byte empty?
            if count > 1 {  // was set neither empty nor singleton?
                return rt.Opcode.set, byte(0)  // neither full nor empty nor singleton
            }
            // else set is still empty or singleton
        } else if b == 0xFF {  // is byte full?
            if count < (i * rt.bits_per_char) {  // was set not full?
                return rt.Opcode.set, byte(0)  // neither full nor empty nor singleton
            } else {
                count += rt.bits_per_char  // set is still full
            }
        } else if (b & (b - 1)) == 0 {  // has byte only one bit?
            if count > 0 {  // was set not empty?
                return rt.Opcode.set, byte(0)  // neither full nor empty nor singleton
            } else {    // set has only one char till now track it
                count ++
                candidate = i
            }
        } else {
            return rt.Opcode.set, byte(0)  // byte is neither empty, full, nor singleton
        }
    }

    if count == 0 {
        return rt.Opcode.fail, byte(0)  // empty set
    } else if count == 1 {  // singleton find character bit inside byte
        mut b := cs.data[candidate]
        mut ichar := candidate * rt.bits_per_char
        if (b & 0xF0) != 0 {
            ichar += 4
            b >>= 4
        }
        if (b & 0x0C) != 0 {
            ichar += 2
            b >>= 2
        }
        if (b & 0x02) != 0 {
            ichar += 1
        }
        return rt.Opcode.char, byte(ichar)
    } else {
        assert count == rt.charset_size * rt.bits_per_char  // full set
        return rt.Opcode.any, byte(0)
    }
}
