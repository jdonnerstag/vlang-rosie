module rosie


// TODO may be rename to SymbolTable
// Symbols Very typical for compiled code, the byte code contains a symbol
// table for static string values. Virtual machine instructions reference
// such symbols by their position / index.
struct Symbols {
pub mut:
	symbols []string
}

// len I wish V-lang had the convention calling x.len actually invokes x.len()
// Determine the number of entries in the symbol table
[inline]
pub fn (s Symbols) len() int { return s.symbols.len }

// get Access the n'th element in the symbol table
[inline]
pub fn (s Symbols) get(i int) string { return s.symbols[i] }

// find Find the symbol index. This to avoid
pub fn (s Symbols) find(data string) ?int {
	for i, e in s.symbols {
		if e == data {
			return i
		}
	}
	return error("Rosie VM: symbol not found: '$data'")
}

// add If the exact same symbol already exist, return its index. Else add the symbol to the table
pub fn (mut s Symbols) add(data string) int {
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
		str += "${i:4d}: '$data'\n"
	}
	return str
}
