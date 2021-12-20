module rosie


[heap]
struct Package {
pub mut:
	fpath string					// The rpl file path, if any
	name string						// Taken from "package" statement, if any, in the rpl file. "main" being the default.
	language string					// e.g. rpl 1.0 => "1.0"
	imports map[string]&Package		// name or alias => package
	bindings []Binding				// Main reason why this is a list: you cannot have references to map entries!!
	parent &Package = 0				// Parent package: grammar's resolve against its parent. And builtin's as general fall-back
	allow_recursions bool			// Only grammar's allow recursive bindings
	package_cache &PackageCache		// A reference to the package cache // TODO replace imports with refs to packages (from the cache)
}

[params]
pub struct NewPackageOptions {
	fpath string					// The rpl file path, if any
	name string						// Taken from "package" statement, if any, in the rpl file. "main" being the default.
	language string					// e.g. rpl 1.0 => "1.0"
	parent &Package = 0				// Parent package: grammar's resolve against its parent. And builtin's as general fall-back
	allow_recursions bool			// Only grammar's allow recursive bindings
	package_cache &PackageCache		// A reference to the package cache // TODO replace imports with refs to packages (from the cache)
}

pub fn new_package(args NewPackageOptions) &Package {
	if args.package_cache == 0 {
		panic("args.package_cache must be a valid reference to a memory address")
	}

	parent := if args.parent == 0 { args.package_cache.builtin() } else { args.parent }

	return &Package{
		fpath: args.fpath
		name: args.name
		language: args.language
		allow_recursions: args.allow_recursions
		package_cache: args.package_cache

		parent: parent
	}
}

// get_idx Search the binding by name within the package only.
// Return -1, if not found
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

// Note that 'name' must be a (full) variable name, not just
// the package name.
pub fn (p &Package) get_import(name string) ? &Package {
	if name == "." || `.` !in name.bytes() {
		return p
	}

	if name.len == 0 || name.starts_with(".") || name.ends_with(".") {
		return error("Invalid binding name: '$name'")
	}

	pkg_alias := name.all_before(".")
	if pkg := p.imports[pkg_alias] {
		return pkg
	}

	return error("Package '$p.name' has no import with name or alias '$pkg_alias'")
}

pub fn (p &Package) get(name string) ? &Binding {
	//eprintln("Find Binding: package=$p.name, name=$name")
	// Determine the package
	pkg := p.get_import(name)?

	bname := if name == "." { name } else { name.all_after(".") }
	if b := pkg.get_(bname) { return b }
	//pkg.print_bindings()

	// Search optional parent packages if the binding name is not referring to
	// an imported package
	//eprintln("package='$pkg.name', parent=0x${voidptr(pkg.parent)}")
	if pkg.has_parent() {
		if rtn := p.parent.get(bname) {
			return rtn
		}
	}

	names := p.package_cache.names()
	//eprintln("Failed: Package '$p.name': Binding with name '$name' not found. Cache contains: ${names}")
	//p.package_cache.print_all_bindings()
	print_backtrace()
	return error("Package '$p.name': Binding with name '$name' not found. Cache contains: ${names}")
}

pub fn (p &Package) has_parent() bool {
	return p.parent != 0
}

// add_binding Add a binding to the package
pub fn (mut p Package) add_binding(b Binding) ? int {
	if p.has_binding(b.name) {
		//print_backtrace()
		return error("Unable to add binding. Pattern name already defined: '$b.name' in file '$p.fpath'")
	}

	rtn := p.bindings.len
	p.bindings << b
	return rtn
}

// The auto-generated str() function is having (recursion?) issues
pub fn (p &Package) str() string {
	return "Package: name='$p.name', fpath='$p.fpath', language='$p.language', allow_recursions='$p.allow_recursions'"
}

// print_bindings Print all bindings in the package (not traversing imports).
pub fn (p Package) print_bindings() {
	println("--- package: '$p.name' ($p.bindings.len) ${'-'.repeat(40)}")
	for i, b in p.bindings {
		println("${i + 1:3d}: ${b.repr()}")
	}
	println("--- end: '$p.name' ${'-'.repeat(40)}")
}
