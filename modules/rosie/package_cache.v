module rosie

pub const builtin = "builtin"

[heap]
struct PackageCache {
pub mut:
	packages []&Package
}

pub fn new_package_cache() &PackageCache {
	mut cache := &PackageCache{}
	cache.add_builtin()
	return cache
}

pub fn (p PackageCache) names() []string {
	mut ar := []string{ cap: p.packages.len }
	for e in p.packages {
		ar << e.name
	}
	return ar
}

pub fn (p PackageCache) get(name string) ? &Package {
	for e in p.packages {
		if name in [e.fpath, e.name] {
			return e
		}
	}

	//print_backtrace()
	return error("Package not found in cache. name='$name'; cache=${p.names()}")
}

[inline]
pub fn (p PackageCache) contains(name string) bool {
	return if _ := p.get(name) { true } else { false }
}

pub fn (mut p PackageCache) add_package(package &Package) ? int {
	if package.name.len == 0 {
		print_backtrace()
		return error("Every package must have name: '$package'")
	}

	if p.contains(package.name) {
		names := p.names()
		return error("A package with same name already exists: '$package.name' ($package.fpath); cache: $names")
	}

	p.packages << package
	return p.packages.len - 1
}

pub fn (mut p PackageCache) add_grammar(parent &Package, file string) ? &Package {
	name := if parent != 0 { "${parent.name}.grammar-${p.packages.len}" } else { "" }
	pkg := rosie.new_package(fpath: name, name: name, parent: parent, allow_recursions: true)
	p.add_package(pkg)?
	return pkg
}

pub fn (p PackageCache) builtin() &Package {
	if pkg := p.get(builtin) {
		return pkg
	} else {
		// panic("Should never happen: Package '${builtin}' not found")
		return 0
	}
}

pub fn (mut cache PackageCache) add_builtin() &Package {
	if pkg := cache.get(builtin) {
		return pkg
	}

	mut pkg := &Package{ name: builtin }

	pkg.bindings << Binding{ name: ".", alias: true, pattern: utf8_pat, package: builtin }
	pkg.bindings << Binding{ name: "$", alias: true, pattern: Pattern{ elem: EofPattern{ eof: true } }, package: builtin  }	  // == '.? $'
	pkg.bindings << Binding{ name: "^" , alias: true, pattern: Pattern{ elem: EofPattern{ eof: false  } }, package: builtin  }	  // == '^ .?'
	pkg.bindings << Binding{ name: "~", func: false, alias: true, pattern: word_boundary_pat, package: builtin }

	// Strictly speaking these bindings are not required. The parser accepts any macro
	// name. expand() will throw an error if the macro name has no implementation.
	// Currently these binding are only used by the cli list subcommand
	pkg.bindings << cache.dummy_macro_binding("backref")
	pkg.bindings << cache.dummy_macro_binding("ci")
	pkg.bindings << cache.dummy_macro_binding("error")
	pkg.bindings << cache.dummy_macro_binding("find")
	pkg.bindings << cache.dummy_macro_binding("findall")
	pkg.bindings << cache.dummy_macro_binding("message")

	cache.add_package(pkg) or {}	// error should never happen. See above test.

	return pkg
}

[inline]
fn (c PackageCache) dummy_macro_binding(name string) Binding {
	return Binding{ name: name, alias: true, package: builtin, pattern: Pattern{ elem: MacroPattern{ name: name} } }
}

pub fn (c PackageCache) print_all_bindings() {
	eprintln("Bindings: -----------------------------------------")
	mut count := 0
	for p in c.packages {
		for b in p.bindings {
			count += 1
			eprintln("${count:4}: ${b.repr()}")
		}
	}
}

pub fn (c PackageCache) print_stats() {
	for p in c.packages {
		eprintln("Package: '$p.name'; len: $p.bindings.len; imports: ${p.imports.keys()}; file: '$p.fpath'")
	}
}