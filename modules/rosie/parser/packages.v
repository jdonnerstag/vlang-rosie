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

[inline]
pub fn (p PackageCache) new_package(name string, fpath string) &Package {
	return &Package{ cache: &p, name: name, fpath: fpath }
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
			if isnil(p.cache) {
				return error("ERROR: for some reason the cache reference is NULL: '$p.name' -> '$pkg' ($fname)")
			}
			if fname in p.cache.packages {
				return p.cache.packages[fname].get(name[pkg.len + 1 ..])
			} else {
				return error("Import system bug: The rpl-file '$fname' has not been loaded and parsed yet")
			}
		} else {
			return error("Package has not been imported: '$pkg' ('$name')")
		}
	} else if name in p.bindings {
		return p.bindings[name]
	} else if isnil(p.cache) == false {
		if pkg := p.cache.packages["builtin"] {
			if isnil(pkg) == false {
				if b := pkg.bindings[name] {
					return b
				}
			}
		}
	}

	return error("Binding with name '$name' not found in package '$p.fpath'")
}

// TODO I don't yet understand the subtleties when returning value. If and when V-lang return references and and when copies.
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

	pkg.bindings["$"] = Binding{ name: "$" }		// TODO There is a flag in charset to flag "must be eof".
	pkg.bindings["."] = Binding{ name: "." }		// TODO May be read and parse char.rpl. For performance reasons, we may want something pre-compiled later on.
	pkg.bindings["^"] = Binding{ name: "^" }		// TODO Don't know yet
	pkg.bindings["~"] = Binding{ name: "~" }		// TODO May be read and parse word.rpl. For performance reasons, we may want something pre-compiled later on.

	pkg.bindings["ci"] = Binding{ name: "ci" }			// TODO Macros are not yet supported at all; haven't thought about how-to
	pkg.bindings["find"] = Binding{ name: "find" }		// TODO Macros are not yet supported at all; haven't thought about how-to
	pkg.bindings["findall"] = Binding{ name: "findall" }	// TODO Macros are not yet supported at all; haven't thought about how-to
	pkg.bindings["keepto"] = Binding{ name: "keepto" }		// TODO Macros are not yet supported at all; haven't thought about how-to

	pkg.bindings["message"] = Binding{ name: "message" }	// TODO Not yet supported at all
	pkg.bindings["error"] = Binding{ name: "error" }		// TODO Not yet supported at all

	pkg.bindings["backref"] = Binding{ name: "backref" }	// TODO Not yet supported at all

	cache.packages["builtin"] = pkg
}