module parser

pub fn test_no_data_no_file() ? {
	p := new_parser()?	// Default parser
	assert p.parser.type_name() == "rosie.parser.rpl_1_3.Parser"
	assert p.language == "1.3"
}

pub fn test_no_rpl() ? {
	mut p := new_parser(rpl: '"a"')?
	assert p.parser.type_name() == "rosie.parser.rpl_1_3.Parser"
	assert p.language == "1.3"

	p = new_parser(rpl: '   a = "a"', language: "1.0")?
	assert p.parser.type_name() == "rosie.parser.rpl_1_3.Parser"
	assert p.language == "1.0"

	p = new_parser(rpl: '-- comment\n a = "a"', language: "stage_0")?
	assert p.parser.type_name() == "rosie.parser.stage_0.Parser"
	assert p.language == "stage_0"
}

pub fn test_with_valid_rpl() ? {
	mut p := new_parser(rpl: 'rpl 1.0')?
	assert p.parser.main.language == "1.0"
	assert p.language == "1.3"

	p = new_parser(rpl: '   rpl 1.1')?
	assert p.parser.main.language == "1.1"
	assert p.language == "1.3"

	p = new_parser(rpl: '   rpl 1.3', language: "3.0")?		// Switch from 3.0 to 1.3 parser
	assert p.parser.main.language == "1.3"
	assert p.language == "1.3"

	p = new_parser(rpl: '-- comment\nrpl 3.0\na = "a"')?	// Switch from 1.3 to 3.0 parser
	assert p.parser.main.language == "3.0"
	assert p.language == "3.0"

	p = new_parser(rpl: '-- comment\r\nrpl 3.1\na = "a"')?
	assert p.language == "3.1"

	p = new_parser(rpl: '-- comment\n   rpl 3.2  \na = "a"')?
	assert p.language == "3.2"

	p = new_parser(rpl: '-- comment\n  -- line 2 \n rpl 3.3\na = "a"')?
	assert p.language == "3.3"
}
