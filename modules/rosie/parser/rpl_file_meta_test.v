module parser

import os
import rosie

fn test_parser_import() ? {
	mut p := new_parser(debug: 0)?
	p.parse(module_mode: true, data: "-- comment \n-- another comment\n\nrpl 3.0\npackage test\nimport net")?
	assert p.parser.main.language == "3.0"
	assert p.parser.main.name == "test"
	assert ("net" in p.parser.main.imports)		// TODO V-bug: Brackets are need
	assert p.package_cache.contains("net") == true
	assert p.package_cache.contains("num") == true
	assert p.package_cache.contains("test") == false
	assert p.package_cache.packages.map(it.name) == ['builtin', 'num', 'net']

	p = new_parser()?
	p.parse(data: "import net")?
	assert p.parser.main.language == ""
	assert p.parser.main.name == "main"
	assert ("net" in p.parser.main.imports)
	assert p.package_cache.contains("net") == true

	p = new_parser()?
	p.parse(data: "import net, word")?
	assert p.parser.main.language == ""
	assert p.parser.main.name == "main"
	assert ("net" in p.parser.main.imports)
	assert ("word" in p.parser.main.imports)
	assert p.package_cache.contains("net") == true
	assert p.package_cache.contains("word") == true

	rosie := rosie.init_rosie()?
	p = new_parser()?
	p.parse(data: 'import net as n, "word" as w')?
	assert p.parser.main.language == ""
	assert p.parser.main.name == "main"
	assert ("n" in p.parser.main.imports)
	assert p.parser.main.imports["n"].fpath == os.real_path(os.join_path(rosie.home, "rpl", "net.rpl"))
	assert ("w" in p.parser.main.imports)
	assert p.parser.main.imports["w"].fpath  == os.real_path(os.join_path(rosie.home, "rpl", "word.rpl"))
}

fn test_parser_import_wo_package_name() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: 'import ../test/backref-rpl as bref')?
	assert p.parser.main.name == "main"
	assert ("bref" in p.parser.main.imports)
	assert p.package_cache.packages.map(it.name) == ['builtin', 'backref-rpl']
}
/* */