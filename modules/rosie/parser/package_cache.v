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

pub fn (p PackageCache) get_idx(pkg_name string) ?int {
	for i, e in p.packages {
		if pkg_name in [e.fpath, e.name] {
			return i
		}
	}
	return error("Package not found in cache: '$pkg_name'; cache contains: ${p.names()}")
}

[inline]
pub fn (p PackageCache) get(pkg_name string) ? &Package {
	return &p.packages[p.get_idx(pkg_name)?]
}

[inline]
pub fn (p PackageCache) contains(pkg_name string) bool {
	return if _ := p.get_idx(pkg_name) { true } else { false }
}

pub fn (mut p PackageCache) add_package(package Package) ? {
	if package.name.len == 0 {
		panic("Every package must have name: '$package'")
	}

	if p.contains(package.name) {
		return error("The package already exists: '$package.fpath'")
	} else {
		p.packages << package
	}
}

[inline]
pub fn (p PackageCache) builtin() ? &Package {
	return p.get(builtin)
}

pub fn (mut cache PackageCache) add_builtin() {
	if cache.contains(builtin) {
		return
	}

	mut pkg := Package{ name: builtin }

	pkg.bindings << Binding{ name: ".", alias: true, pattern: utf8_pat, fpath: builtin }
	pkg.bindings << Binding{ name: "$", alias: true, pattern: Pattern{ min: 1, max: 1, elem: EofPattern{ eof: true } }, fpath: builtin  }	  // == '.? $'
	pkg.bindings << Binding{ name: "^" , alias: true, pattern: Pattern{ min: 1, max: 1, elem: EofPattern{ eof: false  } }, fpath: builtin  }	  // == '^ .?'
	pkg.bindings << Binding{ name: "~", func: true, alias: true, pattern: word_boundary_pat, fpath: builtin }	// TODO May be read and parse word.rpl. For performance reasons, we may want something pre-compiled later on.

	//pkg.bindings["backref"] = Binding{ name: "backref" }	// TODO Not yet supported at all

	cache.add_package(pkg) or {}
}

pub fn (c PackageCache) binding(pkg_name string, var_name string) ? &Binding {
	if idx := c.get_idx(pkg_name) {
		if x := c.packages[idx].get(c, var_name) {
			return x
		} else {
			return error("Binding not found in package: package='$pkg_name', binding='$var_name'")
		}
	}
	return error("Package not found: '$pkg_name'; cache=${c.names()}")
}
