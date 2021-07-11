module compiler

import rosie.runtime as rt

//
// A pattern constructed by the compiler has a tree and a ktable. (The
// ktable is a symbol table, and  a tree node that references a string
// holds an index into the ktable.)
//
// When a pattern is compiled, the code array is created.  A compiled
// pattern consists of its code and ktable.  These are written when a
// compiled pattern is saved to a file, and restored when loaded.
//
// A compiled pattern restored from a file has no tree.
//
struct Pattern {
pub mut:
    code []rt.Slot
    kt rt.Ktable
    tree []TTree
}
