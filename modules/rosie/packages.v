module rosie

pub struct Package {
pub mut:
	fpath string				// The rpl file path, if any
	name string					// Taken from "package" statement, if any, in the rpl file
	language string				// e.g. rpl 1.0 => "1.0"
	imports map[string]string	// name or alias => fpath
	bindings []Binding			// Main reason why this is a list: you cannot have references to map entries !!
	parent string = builtin		// Parent package: grammar's resolve against its parent. And builtin's as general fall-back
	allow_recursions bool		// Only grammar's allow recursions
}

pub fn (p Package) get_idx(name string) int {
	for i, e in p.bindings {
		if e.name == name {
			return i
		}
	}
	return -1
}

pub fn (p Package) has_binding(name string) bool {
	return p.get_idx(name) >= 0
}

// Make sure we pass a reference !!
pub fn (p &Package) get_(name string) ? &Binding {
	idx := p.get_idx(name)
	if idx >= 0 { return &p.bindings[idx] }
	return error("Binding not found: '$name', package='$p.name'")
}

pub fn (p Package) get(cache PackageCache, name string) ? &Binding {
	if name != "." && `.` in name.bytes() {
		pkg_name := name.all_before_last(".")
		if fname := p.imports[pkg_name] {
			pkg := cache.get(fname)?
			var_name := name[pkg_name.len + 1 ..]
			return pkg.get_(var_name)
		}
		//print_backtrace()
		return error("Package has not been imported: '$pkg_name'; binding: '$name'; imports: ${p.imports}")
	}

	mut pkg := p
	for {
		// eprintln("pkg: '$pkg.name', parent: '$pkg.parent'")
		if x := pkg.get_(name) { return x }

		if pkg.parent.len == 0 { break }
		pkg = *cache.get(pkg.parent)?
	}

	//print_backtrace()
	//cache.print_all_bindings()
	return error("Package '$p.name': Binding with name '$name' not found. Cache contains: ${cache.names()}")
}

pub fn (mut p Package) add_binding(b Binding) ? int {
	if p.has_binding(b.name) {
		//print_backtrace()
		return error("Unable to add binding. Pattern name already defined: '$b.name' in file '$p.fpath'")
	}

	rtn := p.bindings.len
	p.bindings << b
	return rtn
}

pub fn (p Package) print_bindings() {
	for b in p.bindings {
		println(b.repr())
	}
}
