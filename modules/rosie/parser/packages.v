module parser

struct Package {
pub:
	fpath string	// The rpl file path, if any

pub mut:
	name string						// Taken from "package" statement, if any, in the rpl file
	language string					// e.g. rpl 1.0 => "1.0"
	imports map[string]string		// alias to full module name (== packages index)
	bindings []Binding				// Main reason why this is a list: you cannot have references to map entries !!
	parent string = builtin			// Parent package
}

pub fn (p Package) has_binding(name string) bool {
	for e in p.bindings {
		if e.name == name {
			return true
		}
	}
	return false
}

pub fn (p Package) get_(name string) ? &Binding {
	for i, e in p.bindings {
		if e.name == name {
			return &p.bindings[i]
		}
	}
	return error("Binding not found: '$name', package='$p.name'")
}

pub fn (p Package) get(cache PackageCache, name string) ? &Binding {
	if name != "." && `.` in name.bytes() {
		pkg_name := name.all_before_last(".")
		if fname := p.imports[pkg_name] {
			return cache.binding(fname, name[pkg_name.len + 1 ..])
		}
		return error("Package has not been imported: '$pkg_name' ('$name')")
	}

	mut pkg := p
	for {
		// eprintln("pkg: '$pkg.name', parent: '$pkg.parent'")
		if x := pkg.get_(name) { return x }

		if pkg.parent.len == 0 { break }
		pkg = cache.get(pkg.parent)?
	}

	// print_backtrace()
	cache.print_all_bindings()
	return error("Package '$p.name': Binding with name '$name' not found. Cache contains: ${cache.names()}")
}

[inline]
pub fn (p Package) get_pattern(cache PackageCache, name string) ? Pattern {
	return p.get(cache, name)?.pattern
}
