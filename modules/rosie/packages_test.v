module rosie

fn test_packages() ? {
	mut cache := new_package_cache()
	mut pnet := Package{ name: "net", fpath: "./rpl/net.rpl", package_cache: cache }
	cache.add_package(pnet)?
	assert cache.contains("net") == true
	assert cache.contains("./rpl/net.rpl") == true
	assert cache.contains("test") == false
	assert cache.get("./rpl/net.rpl")?.name == "net"
	if _ := cache.add_package(pnet) { assert false }

	cache.get("./rpl/net.rpl")?.language = "1.2"
	assert cache.get("./rpl/net.rpl")?.language == "1.2"
}

fn test_resolve_names() ? {
	mut cache := new_package_cache()
	cache.add_package(new_package(name: "net", fpath: "./rpl/net.rpl", package_cache: cache))?
	cache.add_package(new_package(name: "date", fpath: "./rpl/date.rpl", package_cache: cache))?

	mut main := new_package(name: "main", package_cache: cache)
	assert main.parent.name == cache.builtin().name
	main.imports["net"] = cache.get("net")?
	main.imports["date"] = cache.get("date")?

	main.imports["net"].fpath = "./rpl/net.rpl"
	main.imports["date"].fpath = "./rpl/date.rpl"

	main.bindings << Binding{ name: "lvar" }
	cache.get("./rpl/net.rpl")?.bindings << Binding{ name: "net_var" }
	cache.get("./rpl/date.rpl")?.bindings << Binding{ name: "date_var" }

	main.get("lvar") or { assert false }
	assert main.get("lvar")?.name == "lvar"

	assert main.get("net.net_var")?.name == "net_var"
	assert main.get("date.date_var")?.name == "date_var"

	if _ := main.get("abc") { assert false }
	if _ := main.get("date.abc") { assert false }
	if _ := main.get("net.abc") { assert false }
	if _ := main.get("xyz.abc") { assert false }

	assert main.get("$")?.name == "$"
	assert main.get(".")?.name == "."
}
/* */