module parser

fn test_packages() ? {
	mut cache := PackageCache{}
	mut pnet := Package{ cache: &cache, name: "net" }
	cache.add_package("./rpl/net.rpl", pnet)?
	assert cache.contains("./rpl/net.rpl") == true
	assert cache.contains("test") == false
	assert cache.get("./rpl/net.rpl").name == "net"
	if _ := cache.add_package("./rpl/net.rpl", pnet) { assert false }

	pnet.language = "1.2"
	assert cache.get("./rpl/net.rpl").language == "1.2"

	cache.get("./rpl/net.rpl").language = "2.0"
	assert pnet.language == "2.0"

	cache.get("./rpl/net.rpl").imports["test"] = "./rpl/test.rpl"
	assert pnet.imports["test"] == "./rpl/test.rpl"

	// And this one as well. Obviously arrays are treated somehow different ?!?!
	pnet.imports["date"] = "./rpl/date.rpl"
	assert cache.get("./rpl/net.rpl").imports["date"] == "./rpl/date.rpl"
}

fn test_resolve_names() ? {
	mut cache := new_package_cache("")
	cache.add_package("./rpl/net.rpl", &Package{ cache: &cache, name: "net" })?
	cache.add_package("./rpl/date.rpl", &Package{ cache: &cache, name: "date" })?
	cache.add_package("main", &Package{ cache: &cache, name: "main" })?

	cache.get("main").imports["net"] = "./rpl/net.rpl"
	cache.get("main").imports["date"] = "./rpl/date.rpl"

	cache.get("main").bindings["lvar"] = Binding{ name: "lvar" }
	cache.get("./rpl/net.rpl").bindings["net_var"] = Binding{ name: "net_var" }
	cache.get("./rpl/date.rpl").bindings["date_var"] = Binding{ name: "date_var" }

	assert cache.get("main").get("lvar")?.name == "lvar"
	assert cache.get("main").get("net.net_var")?.name == "net_var"
	assert cache.get("main").get("date.date_var")?.name == "date_var"

	if _ := cache.get("main").get("abc") { assert false }
	if _ := cache.get("main").get("date.abc") { assert false }
	if _ := cache.get("main").get("net.abc") { assert false }
	if _ := cache.get("main").get("xyz.abc") { assert false }

	assert cache.get("main").get("$")?.name == "$"
	assert cache.get("main").get(".")?.name == "."
}