module parser

struct Package {
pub:
	fpath string	// The rpl file path, if any

pub mut:
	name string						// Taken from "package" statement, if any, in the rpl file
	language string					// e.g. rpl 1.0 => "1.0"
	imports map[string]string		// alias to file path (== packages index)
	bindings []Binding				// Main reason why this is a list: you cannot have references to map entries !!
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

	if x := p.get_(name) { return x }
	if p.name != builtin {
		if x := cache.binding(builtin, name) { return x }
	}

	return error("Package '$p.name': Binding with name '$name' not found. Cache contains: ${cache.names()}")
}

[inline]
pub fn (p Package) get_pattern(cache PackageCache, name string) ? Pattern {
	return p.get(cache, name)?.pattern
}
