module core_0

import os
import rosie

fn test_parser_import() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: "-- comment \n-- another comment\n\nrpl 1.0\npackage test\nimport net")?
	assert p.main.language == "1.0"
	assert p.main.name == "test"
	assert ("net" in p.main.imports)	// TODO Another V assertion bug. You must use (..) with 'in'
	mut net := p.main.imports["net"]
	mut pkg := p.package_cache.get(net.name)?

	p = new_parser(debug: 0)?
	p.parse(data: "import net")?
	assert p.main.language == ""
	assert p.main.name == "main"
	assert ("net" in p.main.imports)
	net = p.main.imports["net"]
	pkg = p.package_cache.get(net.name)?

	p = new_parser(debug: 0)?
	p.parse(data: "import net, word")?
	assert p.main.language == ""
	assert p.main.name == "main"
	assert ("net" in p.main.imports)
	assert ("word" in p.main.imports)
	net = p.main.imports["net"]
	pkg = p.package_cache.get(net.name)?
	mut word := p.main.imports["word"]
	pkg = p.package_cache.get(word.name)?

	rosie := rosie.init_rosie()?
	p = new_parser(debug: 0)?
	p.parse(data: 'import net as n, "word" as w')?
	assert p.main.language == ""
	assert p.main.name == "main"
	assert ("n" in p.main.imports)
	net = p.main.imports["n"]
	//eprintln(str)
	assert net.fpath == os.real_path(os.join_path(rosie.home, "rpl", "net.rpl"))
	assert ("w" in p.main.imports)
	word = p.main.imports["w"]
	assert word.fpath == os.real_path(os.join_path(rosie.home, "rpl", "word.rpl"))
}

fn test_parser_import_wo_package_name() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: "import ../test/backref-rpl.rpl as bref")?
	assert p.main.name == "main"
	assert ("bref" in p.main.imports)
	mut bref := p.main.imports["bref"]
	assert p.package_cache.contains(bref.name) == true
}