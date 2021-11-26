module rpl

import rosie


fn test_packages() ? {
	mut cache := rosie.PackageCache{}
	mut pnet := rosie.Package{ name: "net", fpath: "./rpl/net.rpl" }
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
	mut cache := rosie.new_package_cache()
	cache.add_package(rosie.Package{ name: "net", fpath: "./rpl/net.rpl" })?
	cache.add_package(name: "date", fpath: "./rpl/date.rpl")?
	cache.add_package(name: "main")?

	cache.get("main")?.imports["net"] = "./rpl/net.rpl"
	cache.get("main")?.imports["date"] = "./rpl/date.rpl"

	cache.get("main")?.bindings << rosie.Binding{ name: "lvar" }
	cache.get("./rpl/net.rpl")?.bindings << rosie.Binding{ name: "net_var" }
	cache.get("./rpl/date.rpl")?.bindings << rosie.Binding{ name: "date_var" }

	cache.get("main") or { assert false }
	cache.get("main")?.get(cache, "lvar") or { assert false }
	assert cache.get("main")?.get(cache, "lvar")?.name == "lvar"

	assert cache.get("main")?.get(cache, "net.net_var")?.name == "net_var"
	assert cache.get("main")?.get(cache, "date.date_var")?.name == "date_var"

	if _ := cache.get("main")?.get(cache, "abc") { assert false }
	if _ := cache.get("main")?.get(cache, "date.abc") { assert false }
	if _ := cache.get("main")?.get(cache, "net.abc") { assert false }
	if _ := cache.get("main")?.get(cache, "xyz.abc") { assert false }

	assert cache.get("main")?.get(cache, "$")?.name == "$"
	assert cache.get("main")?.get(cache, ".")?.name == "."
}

// TODO Is that something we want to support?
// 1. Multiple packages per file
// 2. Returning to package main
// 3. An expression at the end, following normal statements.
//
/* NOT SUPPORTED !!!
fn test_multiple_packages() ? {
	mut p := new_parser()?
	p.parse(data: 'package aaa; a = "a"; package bbb; b = "b"; package main; import aaa; import bbb; {aaa.a bbb.b}')?
	assert p.pattern("*")?.min == 1
	assert p.pattern("*")?.max == 1
	assert p.pattern_str("*") == '"test"'
}
/* */