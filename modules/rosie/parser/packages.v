// ----------------------------------------------------------------------------
// (lexical) Scope and Binding related utils
// ----------------------------------------------------------------------------

module parser


struct Packages {
pub mut:
	cache_dir string
	packages map[string]&Package	// filename => package
}

[heap]
struct Package {
pub:
	cache &Packages
	fpath string	// The rpl file path, if any

pub mut:
	name string						// Taken from "package" statement, if any, in the rpl file
	language string					// e.g. rpl 1.0 => "1.0"
	imports map[string]string		// alias to file path (== packages index)
	bindings map[string]Binding		// variable name => expression
}

[inline]
pub fn (p Packages) contains(fpath string) bool {
	return fpath in p.packages
}

[inline]	// TODO Will this return a copy? That would not be what we want
pub fn (p Packages) get(fpath string) &Package {
	return p.packages[fpath]
}

pub fn (mut p Packages) add_package(fpath string, package &Package) ? {
	if fpath in p.packages {
		return error("The package already exists: '$fpath'")
	}
	p.packages[fpath] = package
}

pub fn (p Package) get(name string) ? Binding {
	if `.` in name.bytes() {
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
	} else {
		return error("Binding with name '$name' not found in package '$p.fpath'")
	}
}

pub fn (p Package) get_pattern(name string) ? &Pattern {
	return &p.get(name)?.pattern
}
