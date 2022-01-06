module parser

pub fn test_no_data_no_file() ? {
	p := new_parser()?	// Default parser
	assert p.major == 1
	assert p.minor == 3
}

pub fn test_no_rpl() ? {
	mut p := new_parser(rpl: '"a"')?
	assert p.major == 1
	assert p.minor == 3

	p = new_parser(rpl: '   a = "a"')?
	assert p.major == 1
	assert p.minor == 3

	p = new_parser(rpl: '-- comment\n a = "a"')?
	assert p.major == 1
	assert p.minor == 3

	p = new_parser(rpl: '-- comment\r\n a = "a"')?
	assert p.major == 1
	assert p.minor == 3

	p = new_parser(rpl: '-- comment\nxyz = "a"')?
	assert p.major == 1
	assert p.minor == 3

	p = new_parser(rpl: '-- comment\n  -- line 2 \n a = "a"')?
	assert p.major == 1
	assert p.minor == 3
}

pub fn test_with_valid_rpl() ? {
	mut p := new_parser(rpl: 'rpl 1.0')?
	assert p.major == 1
	assert p.minor == 0

	p = new_parser(rpl: '   rpl 1.1')?
	assert p.major == 1
	assert p.minor == 1

	p = new_parser(rpl: '-- comment\nrpl 3.0\na = "a"')?
	assert p.major == 3
	assert p.minor == 0

	p = new_parser(rpl: '-- comment\r\nrpl 3.1\na = "a"')?
	assert p.major == 3
	assert p.minor == 1

	p = new_parser(rpl: '-- comment\n   rpl 3.2  \na = "a"')?
	assert p.major == 3
	assert p.minor == 2

	p = new_parser(rpl: '-- comment\n  -- line 2 \n rpl 3.3\na = "a"')?
	assert p.major == 3
	assert p.minor == 3
}
