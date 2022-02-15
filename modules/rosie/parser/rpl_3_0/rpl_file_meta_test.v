module rpl_3_0


fn test_dummy() {
	// TODO Until we have an rpl-3 file to import
}

/*
RPL-3 parser itself is not able to import rpl-1 files. Only ParserDelegator can do this
fn test_parser_import() ? {
	mut p := new_parser()?
	p.parse(module_mode: true, data: "-- comment \n-- another comment\n\nrpl 3.0\npackage test\nimport net")?
	assert p.current.language == "3.0"
	assert p.main.name == "test"
	assert p.main.name == "test"
	assert p.current.name == "test"
	assert ("net" in p.current.imports)		// TODO V-bug: Brackets are need
	assert p.package_cache.contains("net") == true
	assert p.package_cache.packages.map(it.name) == ['builtin', 'test', 'net', 'num']

	p = new_parser()?
	p.parse(data: "import net")?
	assert p.current.language == ""
	assert p.current.name == "main"
	assert ("net" in p.current.imports)
	assert p.package_cache.contains("net") == true

	p = new_parser()?
	p.parse(data: "import net, word")?
	assert p.current.language == ""
	assert p.current.name == "main"
	assert ("net" in p.current.imports)
	assert ("word" in p.current.imports)
	assert p.package_cache.contains("net") == true
	assert p.package_cache.contains("word") == true

	rosie := rosie.init_rosie()?
	p = new_parser()?
	p.parse(data: 'import net as n, "word" as w')?
	assert p.current.language == ""
	assert p.current.name == "main"
	assert ("n" in p.current.imports)
	assert p.current.imports["n"].fpath == os.real_path(os.join_path(rosie.home, "rpl", "net.rpl"))
	assert ("w" in p.current.imports)
	assert p.current.imports["w"].fpath  == os.real_path(os.join_path(rosie.home, "rpl", "word.rpl"))
}
/*
RPL-3 parser itself is not able to import rpl-1 files. Only ParserDelegator can do this
fn test_parser_import_wo_package_name() ? {
	mut p := new_parser(debug: 0)?
	p.parse(data: 'import "../test/backref-rpl" as bref')?
	assert p.current.name == "main"
	assert ("bref" in p.current.imports)
	assert p.package_cache.packages.map(it.name) == ['builtin', 'backref-rpl', 'backref-rpl.grammar_2', 'backref-rpl.grammar_3', 'backref-rpl.grammar_4']
}
/* */