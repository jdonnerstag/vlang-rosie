module rosie

fn test_bindings() ? {
	mut p := new_package(name: "main")

	mut b1 := p.new_binding(name: "b1")?
	assert b1.name == "b1"
	assert b1.package == "main"
	assert p.bindings.len == 1

	mut b2 := p.new_binding(name: "b2")?
	assert p.bindings.len == 2

	if _ := p.new_binding(name: "b1") { assert false } 	// already exists

	assert p.get("b1")?.name == b1.name
	assert p.get("b2")?.name == "b2"
	if _ := p.get("test") { assert false } 		// does not exist

	assert voidptr(p.context(b1)?) == voidptr(p)
	assert voidptr(p.context(b2)?) == voidptr(p)
}

fn test_parent() ? {
	mut builtin_ := new_package(name: "builtin")
	builtin_.new_binding(name: "~")?
	builtin_.new_binding(name: ".")?
	assert builtin_.bindings.len == 2

	mut p := new_package(name: "main", parent: builtin_)
	assert p.has_parent() == true

	assert p.get("~")?.package == "builtin"
	assert p.get(".")?.package == "builtin"
	assert p.context(p.get(".")?)? == p		// The context remain with "main" package

	p.new_binding(name: "b1")?
	p.new_binding(name: "~")?	// supersede builtin_

	assert p.get("b1")?.package == "main"
	assert p.get("~")?.package == "main"
	assert voidptr(p.context(p.get("b1")?)?) == voidptr(p)		// The context remain with "main" package
}

fn test_import() ? {
	mut p := new_package(name: "main")
	p.new_binding(name: "m1")?

	mut net := new_package(name: "net")
	p.new_import("net_alias", net)?
	net.new_binding(name: "n1")?

	assert p.get("m1")?.package == "main"
	assert p.get("net_alias.n1")?.package == "net"
	if _ := p.get("n1") { assert false }
}

fn test_grammar() ? {
	mut main := new_package(name: "main")
	main.new_binding(name: "m1")?

	mut grammar := main.new_grammar("my_grammar")?
	grammar.new_binding(name: "g1")?
	main.new_binding(name: "gp", grammar: grammar.name)?	// a public grammar variable. Can access package and grammar bindings, and is visible from within the grammar

	assert main.get("m1")?.package == "main"		// "main" binding
	assert grammar.get("m1")?.package == "main"		// "main" binding, also visible in grammar because of parent relationship

	assert grammar.get("g1")?.package == "my_grammar"	// "grammar" binding
	if _ := main.get("g1") { assert false }				// not visible in "main"
	assert main.get("my_grammar.g1")?.package == "my_grammar"	// access from "main" with package prefix

	assert main.get("gp")?.package == "main"		// public grammar bindings are visible in "main"
	assert main.get("gp")?.grammar == "my_grammar"	// public grammar bindings are associated with a grammar
	assert grammar.get("gp")?.package == "main"		// ... parent relationship

	mut b, mut pkg := main.get_bp("m1")?
	assert b.name == "m1"
	assert b.package == "main"
	assert b.grammar == ""
	assert pkg.name == "main"

	b, pkg = grammar.get_bp("g1")?
	assert b.name == "g1"
	assert b.package == "my_grammar"
	assert b.grammar == ""
	assert pkg.name == "my_grammar"

	b, pkg = main.get_bp("gp")?
	assert b.name == "gp"
	assert b.package == "main"
	assert b.grammar == "my_grammar"
	assert pkg.name == "my_grammar"

	b, pkg = main.get_bp("my_grammar.g1")?
	assert b.name == "g1"
	assert b.package == "my_grammar"
	assert b.grammar == ""
	assert pkg.name == "my_grammar"
}
/* */
