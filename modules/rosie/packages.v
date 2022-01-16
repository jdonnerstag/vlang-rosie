module rosie


[heap]
struct Package {
pub mut:
	fpath string					// The rpl file path, if any
	name string						// Taken from "package" statement, if any, in the rpl file. "main" being the default.
	language string
	imports map[string]&Package		// name or alias => package. Grammars will be added to 'imports' as well.
	bindings []Binding				// Main reason why this is a list: you cannot have references to map entries!!
	parent &Package = 0				// Parent package: grammar's resolve against their parents. And builtin package as general fall-back
	allow_recursions bool			// Only grammar's allow recursive bindings
}

[params]
pub struct NewPackageOptions {
	fpath string					// The rpl file path, if any
	name string						// Taken from "package" statement, if any, in the rpl file. "main" being the default.
	parent &Package = 0				// Parent package: grammar's resolve against its parent. And builtin's as general fall-back
	allow_recursions bool			// Only grammar's allow recursive bindings
}

pub fn new_package(args NewPackageOptions) &Package {
	return &Package{
		fpath: args.fpath
		name: args.name
		parent: args.parent
		allow_recursions: args.allow_recursions
	}
}

// get_idx Search the binding by name within the package only.
fn (p Package) get_idx(name string) ? int {
	for i, e in p.bindings {
		if e.name == name {
			return i
		}
	}
	return error("Binding not found: '$name', package='$p.name'")
}

pub fn (p Package) has_binding(name string) bool {
	return if _ := p.get_idx(name) { true } else { false }
}

// Make sure we pass a reference !!
// Find in the current package only (no grammars, no imports)
fn (p &Package) get_internal(name string) ? &Binding {
	idx := p.get_idx(name)?
	return &p.bindings[idx]
}

// Note that 'name' must be a (full) variable name, not just
// the package name.
fn (p &Package) sub_package(name string) ? &Package {
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

pub fn (p &Package) has_parent() bool {
	return p.parent != 0
}

pub fn (p &Package) get(name string) ? &Binding {
	b, _ := p.get_bp(name)?
	return b
}

pub fn (p &Package) get_bp(name string) ? (&Binding, &Package) {
	if name.count(".") > 1 {
		return error("Invalid name for a binding: '$name' (only 1 '.' is allowed)")
	}

	//eprintln("Find Binding: package=$p.name, name=$name")
	// Determine the package
	mut pkg := p.sub_package(name)?

	bname := if name == "." { name } else { name.all_after(".") }
	if b := pkg.get_internal(bname) {
		pkg = pkg.context(b)?
		return b, pkg
	}
	//pkg.print_bindings()

	// Search optional parent packages if the binding name is not referring to
	// an imported package
	//eprintln("package='$pkg.name', parent=0x${voidptr(pkg.parent)}")
	if pkg.has_parent() {
		if rtn := p.parent.get(bname) {
			return rtn, pkg		// We return the original, and not the parent
		}
	}

	//eprintln("Failed: Package '$p.name': Binding with name '$name' not found")
	//p.package_cache.print_all_bindings()
	//print_backtrace()
	return error("Package '$p.name' has no binding with name '$name'")
}

fn (p &Package) context(b Binding) ? &Package {
	if b.grammar.len == 0 || b.grammar == p.name {
		return p
	}

	return p.imports[b.grammar] or {
		//print_backtrace()
		return error("Package '$p.name' has no grammar with name '$b.grammar' => ${p.imports.keys()}")
	}
}

// add_binding Add a binding to the package
pub fn (mut p Package) new_binding(b Binding) ? &Binding {
	if p.has_binding(b.name) {
		//print_backtrace()
		return error("Unable to add binding. Binding with same name already defined: '$b.name' in file '$p.name'")
	}

	p.bindings << Binding{ ...b, package: p.name }
	return &p.bindings[p.bindings.len - 1]
}

pub fn (mut p Package) is_grammar_package() bool {
	return p.allow_recursions == true
}

pub fn (mut p Package) new_grammar(name string) ? &Package {
	gr_name := /* p.name + "." + */ name

	pkg := new_package(
		name: gr_name
		fpath: gr_name
		parent: &p
		allow_recursions: true
	)

	p.new_import(gr_name, pkg)?
	return pkg
}

pub fn (mut p Package) new_import(name string, pkg &Package) ? {
	if name in p.imports {
		return error("Package '$p.name': an import or grammar with the same name already exists: '$name'")
	}

	p.imports[name] = pkg
}

pub fn (p &Package) builtin() &Package {
	mut pp := p
	for isnil(pp) == false {
		if pp.name == "builtin" {
			return pp
		}
		pp = pp.parent
	}
	panic("Package '$p.name' has no 'builtin' parent")
}

// The auto-generated str() function is having (recursion?) issues
pub fn (p &Package) str() string {
	return "Package: name='$p.name', fpath='$p.fpath', allow_recursions='$p.allow_recursions'"
}

// print_bindings Print all bindings in the package (not traversing imports).
pub fn (p Package) print_bindings() {
	println("--- package: '$p.name' ($p.bindings.len) ${'-'.repeat(40)}")
	for i, b in p.bindings {
		println("${i + 1:3d}: ${b.repr()}")
	}
	println("--- end: '$p.name' ${'-'.repeat(40)}")
}
