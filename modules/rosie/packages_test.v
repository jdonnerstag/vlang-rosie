module rosie

fn test_packages() ? {
	mut cache := PackageCache{}
	mut pnet := Package{ name: "net", fpath: "./rpl/net.rpl", package_cache: &cache }
	cache.add_package(pnet)?
	assert cache.contains("net") == true
	assert cache.contains("./rpl/net.rpl") == true
	assert cache.contains("test") == false
	assert cache.get("./rpl/net.rpl")?.name == "net"
	if _ := cache.add_package(pnet) { assert false }

	cache.get("./rpl/net.rpl")?.language = "1.2"
	assert cache.get("./rpl/net.rpl")?.language == "1.2"

	cache.get("./rpl/net.rpl")?.imports["test"] = "./rpl/test.rpl"
	assert cache.get("./rpl/net.rpl")?.imports["test"] == "./rpl/test.rpl"
}

fn test_resolve_names() ? {
	mut cache := new_package_cache()
	cache.add_package(Package{ name: "net", fpath: "./rpl/net.rpl", package_cache: &cache })?
	cache.add_package(name: "date", fpath: "./rpl/date.rpl", package_cache: &cache)?
	cache.add_package(name: "main", package_cache: &cache)?

	cache.get("main")?.imports["net"] = "./rpl/net.rpl"
	cache.get("main")?.imports["date"] = "./rpl/date.rpl"

	cache.get("main")?.bindings << Binding{ name: "lvar" }
	cache.get("./rpl/net.rpl")?.bindings << Binding{ name: "net_var" }
	cache.get("./rpl/date.rpl")?.bindings << Binding{ name: "date_var" }

	cache.get("main") or { assert false }
	cache.get("main")?.get("lvar") or { assert false }
	assert cache.get("main")?.get("lvar")?.name == "lvar"

	assert cache.get("main")?.get("net.net_var")?.name == "net_var"
	assert cache.get("main")?.get("date.date_var")?.name == "date_var"

	if _ := cache.get("main")?.get("abc") { assert false }
	if _ := cache.get("main")?.get("date.abc") { assert false }
	if _ := cache.get("main")?.get("net.abc") { assert false }
	if _ := cache.get("main")?.get("xyz.abc") { assert false }

	assert cache.get("main")?.get("$")?.name == "$"
	assert cache.get("main")?.get(".")?.name == "."
}
