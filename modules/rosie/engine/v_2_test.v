
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

fn new_0_parser() ? ParserV1 {
	return ParserV1{ main: &Package{ str: "test" }}
}

fn new_parser() ? Parser {
	//return Parser(new_0_parser()?)		// TODO I raised in an issue. I think it is a bug. It doesn't translate into proper C-code
	p := new_0_parser() or { return err }
	return Parser(p)
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
}
