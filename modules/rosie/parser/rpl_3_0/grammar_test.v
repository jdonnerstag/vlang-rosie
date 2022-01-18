module rpl_3_0

// RPL 3.0 does not support the grammar syntax any longer
fn test_import() ? {
	mut p := new_parser(debug: 0)?
	if _ := p.parse(data: '
grammar
	yyy = "a"
in
	xxx = yyy
end
') { assert false }
}
/* */