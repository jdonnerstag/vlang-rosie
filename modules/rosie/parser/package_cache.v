module parser

const builtin = "builtin"

struct PackageCache {
pub:
	cache_dir string
pub mut:
	packages []Package
}

pub fn new_package_cache(cache_dir string) PackageCache {
	mut cache := PackageCache{ cache_dir: cache_dir }
	cache.add_builtin()
	return cache
}

pub fn (p PackageCache) names() []string {
	mut ar := []string{ cap: p.packages.len }
	for e in p.packages { ar << e.name }
	return ar
}

pub fn (p PackageCache) get_idx(name string) ?int {
	for i, e in p.packages {
		if name in [e.fpath, e.name] {
			return i
		}
	}
	return error("Package not found. name='$name'; cache=${p.names()}")
}

[inline]
pub fn (p PackageCache) get(name string) ? &Package {
	return &p.packages[p.get_idx(name)?]
}

[inline]
pub fn (p PackageCache) contains(name string) bool {
	return if _ := p.get_idx(name) { true } else { false }
}

pub fn (mut p PackageCache) add_package(package Package) ? int {
	if package.name.len == 0 {
		return error("Every package must have name: '$package'")
	}

	if p.contains(package.name) {
		return error("A package with same name already exists: '$package.name' ($package.fpath)")
	}

	p.packages << package
	return p.packages.len - 1
}

pub fn (mut p PackageCache) add_grammar(package string) ? &Package {
	name := "${package}.grammar-${p.packages.len}"
	idx := p.add_package(fpath: name, name: name, parent: package, allow_recursions: true)?
	return &p.packages[idx]
}

[inline]
pub fn (p PackageCache) builtin() ? &Package {
	return p.get(builtin)
}

pub fn (mut cache PackageCache) add_builtin() {
	if cache.contains(builtin) {
		return
	}

	mut pkg := Package{ name: builtin, parent: "" }

	pkg.bindings << Binding{ name: ".", alias: true, pattern: utf8_pat, package: builtin }
	pkg.bindings << Binding{ name: "$", alias: true, pattern: Pattern{ elem: EofPattern{ eof: true } }, package: builtin  }	  // == '.? $'
	pkg.bindings << Binding{ name: "^" , alias: true, pattern: Pattern{ elem: EofPattern{ eof: false  } }, package: builtin  }	  // == '^ .?'
	pkg.bindings << Binding{ name: "~", func: true, alias: true, pattern: word_boundary_pat, package: builtin }	// TODO May be read and parse word.rpl. For performance reasons, we may want something pre-compiled later on.

	cache.add_package(pkg) or {}
}

pub fn (c PackageCache) print_all_bindings() {
	eprintln("Bindings: -----------------------------------------")
	for p in c.packages {
		for b in p.bindings {
			eprintln("  ${b.repr()}")
		}
	}
}
