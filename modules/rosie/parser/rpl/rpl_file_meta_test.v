module rpl

import os
import rosie

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

	rosie := rosie.init_rosie()?
	p = new_parser(data: 'import net as n, "word" as w', debug: 0)?
	assert p.package().language == ""
	assert p.package().name == "main"
	assert "n" in p.package().imports
	mut str := p.package().imports["n"]	// TODO There is some V bug preventing to use the map expr in assert
	eprintln(str)
	assert str == os.real_path(os.join_path(rosie.home, "rpl", "net.rpl"))
	assert "w" in p.package().imports
	str = p.package().imports["w"]	// TODO There is some V bug preventing to use the map expr in assert
	assert str == os.real_path(os.join_path(rosie.home, "rpl", "word.rpl"))
}