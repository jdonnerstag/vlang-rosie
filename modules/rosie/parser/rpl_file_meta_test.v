module parser


fn test_parser_import() ? {
	mut p := new_parser(data: "-- comment \n-- another comment\n\nrpl 1.0\npackage test\nimport net", debug: 0)?
	assert p.package().language == "1.0"
	assert p.package().name == "test"
	assert "net" in p.package().imports

	p = new_parser(data: "import net", debug: 0)?
	assert p.package().language == ""
	assert p.package().name == "main"
	assert "net" in p.package().imports

	p = new_parser(data: "import net, word", debug: 0)?
	assert p.package().language == ""
	assert p.package().name == "main"
	assert "net" in p.package().imports
	assert "word" in p.package().imports

	p = new_parser(data: 'import net as n, "word" as w', debug: 0)?
	assert p.package().language == ""
	assert p.package().name == "main"
	assert "n" in p.package().imports
	eprintln(p.package().imports["n"])
	assert p.package().imports["n"] == r"C:\source_code\vlang\vlang-rosie\rpl\net.rpl"
	assert "w" in p.package().imports
	assert p.package().imports["w"] == r"C:\source_code\vlang\vlang-rosie\rpl\word.rpl"
}
