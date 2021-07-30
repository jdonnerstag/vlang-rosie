// ----------------------------------------------------------------------------
// (lexical) Scope and Binding related utils
// ----------------------------------------------------------------------------

module parser


[heap]
struct PackageCache {
pub:
	cache_dir string
pub mut:
	packages map[string]&Package	// filename => package
}

[heap]
struct Package {
pub:
	cache &PackageCache
	fpath string	// The rpl file path, if any

pub mut:
	name string						// Taken from "package" statement, if any, in the rpl file
	language string					// e.g. rpl 1.0 => "1.0"
	imports map[string]string		// alias to file path (== packages index)
	bindings map[string]Binding		// variable name => expression
}

pub fn new_package_cache(cache_dir string) PackageCache {
	mut cache := PackageCache{
		cache_dir: cache_dir,
	}

	cache.add_builtin()
	return cache
}

[inline]
pub fn (p PackageCache) contains(fpath string) bool {
	return fpath in p.packages
}

[inline]	// TODO Will this return a copy? That would not be what we want
pub fn (p PackageCache) get(fpath string) &Package {
	return p.packages[fpath]
}

pub fn (mut p PackageCache) add_package(fpath string, package &Package) ? {
	if fpath in p.packages {
		return error("The package already exists: '$fpath'")
	}
	p.packages[fpath] = package
}

pub fn (p Package) get(name string) ? Binding {
	if name != "." && `.` in name.bytes() {
		pkg := name.before(".")
		if pkg in p.imports {
			fname := p.imports[pkg]
			if fname in p.cache.packages {
				return p.cache.packages[fname].get(name[pkg.len + 1 ..])
			} else {
				return error("No import found for: '$fname' in package '$p.fpath'")
			}
		} else {
			return error("Package has not been imported: '$pkg' ('$name')")
		}
	} else if name in p.bindings {
		return p.bindings[name]
	} else if name in p.cache.packages["builtin"].bindings {
		return p.cache.packages["builtin"].bindings[name]
	} else {
		return error("Binding with name '$name' not found in package '$p.fpath'")
	}
}

[inline]
pub fn (p Package) get_pattern(name string) ? &Pattern {
	return &p.get(name)?.pattern
}

[inline]
pub fn (p PackageCache) builtin() &Package {
	return p.get("builtin")
}

pub fn (mut cache PackageCache) add_builtin() {
	mut pkg := &Package{ cache: &cache }

	pkg.bindings["$"] = Binding{ name: "$" }
	pkg.bindings["."] = Binding{ name: "." }
	pkg.bindings["^"] = Binding{ name: "^" }
	pkg.bindings["~"] = Binding{ name: "~" }

	pkg.bindings["ci"] = Binding{ name: "ci" }
	pkg.bindings["find"] = Binding{ name: "find" }
	pkg.bindings["findall"] = Binding{ name: "findall" }
	pkg.bindings["keepto"] = Binding{ name: "keepto" }

	pkg.bindings["message"] = Binding{ name: "message" }
	pkg.bindings["error"] = Binding{ name: "error" }

	pkg.bindings["backref"] = Binding{ name: "backref" }

	cache.packages["builtin"] = pkg
}