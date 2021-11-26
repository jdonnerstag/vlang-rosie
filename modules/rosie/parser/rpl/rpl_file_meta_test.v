module rpl

import os
import rosie

fn test_parser_import() ? {
	mut p := new_parser()?
	p.parse(module_mode: true, data: "-- comment \n-- another comment\n\nrpl 1.0\npackage test\nimport net")?
	assert p.package().language == "1.0"
	assert p.package == "test"
	assert p.main.name == "test"
	assert p.package().name == "test"
	assert "net" in p.package().imports
	mut fname := p.package().imports["net"]
	mut pkg := p.package_cache.get(fname)?
	assert p.package_cache.packages.map(it.name) == ['builtin', 'test', 'net', 'num']

	p = new_parser()?
	p.parse(data: "import net")?
	assert p.package().language == ""
	assert p.package().name == "main"
	assert "net" in p.package().imports
	fname = p.package().imports["net"]
	pkg = p.package_cache.get(fname)?

	p = new_parser()?
	p.parse(data: "import net, word")?
	assert p.package().language == ""
	assert p.package().name == "main"
	assert "net" in p.package().imports
	assert "word" in p.package().imports
	fname = p.package().imports["net"]
	pkg = p.package_cache.get(fname)?
	fname = p.package().imports["word"]
	pkg = p.package_cache.get(fname)?

	rosie := rosie.init_rosie()?
	p = new_parser()?
	p.parse(data: 'import net as n, "word" as w')?
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

fn test_parser_import_wo_package_name() ? {
	mut p := new_parser(debug: 55)?
	p.parse(data: 'import "../test/backref-rpl" as bref')?
	assert p.package().name == "main"
	assert "bref" in p.package().imports
	mut fname := p.package().imports["bref"]
	assert p.package_cache.packages.map(it.name) == ['builtin', 'backref-rpl', 'backref-rpl.grammar-2', 'backref-rpl.grammar-3', 'backref-rpl.grammar-4']
	mut pkg := p.package_cache.get(fname)?
}
/* */