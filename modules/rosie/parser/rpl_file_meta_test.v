module parser

import os
import rosie

fn test_parser_import() ? {
	mut p := new_parser()?
	p.parse(module_mode: true, data: "-- comment \n-- another comment\n\nrpl 3.0\npackage test\nimport net")?
	assert p.parser.current.language == "3.0"
	assert p.parser.main.name == "test"
	assert p.parser.main.name == "test"
	assert p.parser.current.name == "test"
	assert ("net" in p.parser.current.imports)		// TODO V-bug: Brackets are need
	assert p.package_cache.contains("net") == true
	assert p.package_cache.packages.map(it.name) == ['builtin', 'test', 'net', 'num']

	p = new_parser()?
	p.parse(data: "import net")?
	assert p.parser.current.language == ""
	assert p.parser.current.name == "main"
	assert ("net" in p.parser.current.imports)
	assert p.package_cache.contains("net") == true

	p = new_parser()?
	p.parse(data: "import net, word")?
	assert p.parser.current.language == ""
	assert p.parser.current.name == "main"
	assert ("net" in p.parser.current.imports)
	assert ("word" in p.parser.current.imports)
	assert p.package_cache.contains("net") == true
	assert p.package_cache.contains("word") == true

	rosie := rosie.init_rosie()?
	p = new_parser()?
	p.parse(data: 'import net as n, "word" as w')?
	assert p.parser.current.language == ""
	assert p.parser.current.name == "main"
	assert ("n" in p.parser.current.imports)
	assert p.parser.current.imports["n"].fpath == os.real_path(os.join_path(rosie.home, "rpl", "net.rpl"))
	assert ("w" in p.parser.current.imports)
	assert p.parser.current.imports["w"].fpath  == os.real_path(os.join_path(rosie.home, "rpl", "word.rpl"))
}

fn test_parser_import_wo_package_name() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: 'import "../test/backref-rpl" as bref')?
	assert p.parser.current.name == "main"
	assert ("bref" in p.parser.current.imports)
	assert p.package_cache.packages.map(it.name) == ['builtin', 'backref-rpl', 'backref-rpl.grammar-2', 'backref-rpl.grammar-3', 'backref-rpl.grammar-4']
}
/* */