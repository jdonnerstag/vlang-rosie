module compiler_backend

import rosie.runtime as rt

// Check whether a charset is empty (returns IFail), singleton (IChar),
// full (IAny), or none of those (ISet). When singleton, '*c' returns
// which character it is. (When generic set, the set was the input,
// so there is no need to return it.)
fn charsettype(cs rt.Charset) (rt.Opcode, byte) {
    bits := int(sizeof(rt.Slot) * rt.bits_per_char)
    mut count := 0
    mut candidate := -1  // candidate position for the singleton char
    for i in 0 .. cs.data.len {  // for each slot
        b := cs.data[i]
        if b == 0 {  // is byte empty?
            if count > 1 {  // was set neither empty nor singleton?
                return rt.Opcode.set, byte(0)  // neither full nor empty nor singleton
            }
            // else set is still empty or singleton
        } else if b == -1 {  // is byte full?
            if count < (i * bits) {  // was set not full?
                return rt.Opcode.set, byte(0)  // neither full nor empty nor singleton
            } else {
                count += bits  // set is still full
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
    } else if count == cs.data.len * bits { // full set
        return rt.Opcode.any, byte(0)
    } else {  // singleton find character bit inside byte
        assert count == 1

        mut b := cs.data[candidate]
        mut ichar := candidate * bits

        for i in 0 .. bits {
            if (b & 0x01) != 0 {
                ichar += i
                break
            }
            b >>= 1
        }
        return rt.Opcode.char, byte(ichar)
    }
}
