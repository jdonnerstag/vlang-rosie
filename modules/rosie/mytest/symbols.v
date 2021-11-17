module mytest

struct Symbols {
pub mut:
	symbols []string
}

pub fn (s Symbols) len() int {
	return s.symbols.len
}

pub fn (s Symbols) get(i int) string {
	return s.symbols[i]
}

pub fn (s Symbols) find(data string) ?int {
	for i, e in s.symbols {
		if e == data {
			return i
		}
	}
	return none
}

pub fn (mut s Symbols) add(data string) int {
	if idx := s.find(data) {
		return idx
	}

	len := s.symbols.len
	s.symbols << data
	return len
}
