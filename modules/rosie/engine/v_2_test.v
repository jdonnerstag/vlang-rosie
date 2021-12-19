
[heap]
struct Package {
	str string
}

interface Parser {
	main &Package
}

struct ParserV1 {
mut:
	main &Package
}

fn new_parser() ? Parser {
	return ParserV1{ main: &Package{ str: "test" }}
}

struct Engine {
	parser Parser
}

pub fn test_1() ? {
	parser := new_parser()?
	assert parser.main.str == "test"
	eprintln(voidptr(parser.main))
	e := Engine{ parser: parser }
	assert e.parser.main.str == "test"
	eprintln(voidptr(e.parser.main))

	f := e
	assert f.parser.main.str == "test"
	eprintln(voidptr(f.parser.main))
	assert false
}
