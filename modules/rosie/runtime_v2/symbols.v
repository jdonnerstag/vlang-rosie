module runtime_v2

/* The below comments are from the original rosie C-code. Not sure how much
   they are relevant for the V implementation as well.

   TODO: symbols holds constant captures (Crosieconst) but we want
   those to be unicode, and symbols cannot hold unicode because it is
   implemented using null-terminated strings.  In future, even rosie
   pattern names could be unicode, and that is what symbols was meant
   for.  So we should change the impl to store string length, too.

   ALSO: For ahead-of-time compilation (specifically, to produce
   library files), we need an index of entry points into a code
   vector. Since the entry points are pattern names, all of which are
   in the symbols, we will enhance the symbols to store an unsigned
   32-bit index into the instruction vector.  That index will be used
   by 'call' instructions.

   N.B. It's possible for two distinct captures to have the same
   capture name, and we compact the symbols to remove duplicates. It
   should NOT be possible for two entry points in the same namespace
   to have the same capture name, so we can continue to compact the
   symbols.  When consolidating multiple entries that have the same
   name, we should observe that only one of them has an entry point
   defined.

   New capture table format:
   'size' is the number of entries;
   'block' is a byte array that holds the capture names;
   'element' is an array of structures (see below);
   Each element contains:
   'start' is the first character of the capture name in 'block';
   'len' is the number of bytes in the capture name;
   'entrypoint' is an index into the code vector IFF this name is an entry point;

   Symbols indexing begins at 1, which reserves the 0th element for RPL
   library use.  The first element (at index 0) points to the default
   prefix name for the library, stored in 'block'.  When there is not
   a prefix (such as for a top-level namespace), the length field will
   be 0.
*/

type SymbolType = string | Charset

// TODO may be rename to SymbolTable
// Symbols Very typical for compiled code, the byte code contains a symbol
// table for static string values. Virtual machine instructions reference
// such symbols by their position / index.
struct Symbols {
pub mut:
  	symbols []SymbolType
}

// new_symbols Create a new, empty, symbol table
pub fn new_symbol_table() Symbols { return Symbols{} }

// len I wish V-lang had the convention calling x.len actually invokes x.len()
// Determine the number of entries in the symbol table
[inline]
pub fn (s Symbols) len() int { return s.symbols.len }

// get Access the n'th element in the symbol table, assuming it is a string
[inline]
pub fn (s Symbols) get(i int) string { return s.symbols[i] as string }

// get Access the n'th element in the symbol table, assuming it is a Charset
[inline]
pub fn (s Symbols) get_charset(i int) Charset { return s.symbols[i] as Charset }

// get Access the n'th element in the symbol table
[inline]
fn (s Symbols) get_(i int) SymbolType { return s.symbols[i] }

// find Find the symbol index. This to avoid
pub fn (s Symbols) find(data SymbolType) ?int {
    for i, e in s.symbols {
        if e is string {
            if data is string {
                if e == data {
                    return i
                }
            }
        } else if e is Charset {
            if data is Charset {
                if e.is_equal(data) {
                    return i
                }
            }
        }
    }
    return error("Rosie VM: symbol not found: '$data'")
}

// add If the exact same symbol already exist, return its index. Else add the symbol to the table
pub fn (mut s Symbols) add(data SymbolType) int {
    if idx := s.find(data) {
        return idx
    }

    len := s.symbols.len
    s.symbols << data
    return len
}

// repr Create a string representation of the symbol table
pub fn (s Symbols) repr() string {
    mut str := "Symbol table:\n"
    for i, data in s.symbols {
        str += "${i:4d}: "
        str += match data {
            string { "'$data'" }
            Charset { "${data.repr()}" }
        }
      	str += "\n"
    }
	return str
}
