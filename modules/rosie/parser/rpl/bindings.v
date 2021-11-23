// ----------------------------------------------------------------------------
// (lexical) Scope and Binding related utils
// ----------------------------------------------------------------------------

module rpl

import rosie


pub fn (p &Parser) package() &rosie.Package {
	// Note: 'fn (p &Parser)' It is important to pass a pointer. Otherwise the
	// V-compiler will make a copy of 'p', which is definitely not what we want.
	if p.package.len == 0 {
		return &p.main
	}

	return p.package_cache.get(p.package) or {
		panic("Parser: package not found in cache?? name='$p.package'; cache=${p.package_cache.names()}")
	}
}

fn (p Parser) package_by_varname(name string) ? &rosie.Package {
	mut pkg := p.package()
	if name != "." && `.` in name.bytes() {
		pkg_name := name.all_before_last(".")
		if fname := pkg.imports[pkg_name] {
			return p.package_cache.get(fname)
		}
	}

	if _ := pkg.get_(name) {
		return pkg
	}

	for pkg.parent.len > 0 {
		pkg = p.package_cache.get(pkg.parent)?
		if _ := pkg.get_(name) {
			return pkg
		}
	}

	return error("Binding not found. name='$name' in package='$p.package' (file: '${p.package().fpath}')")
}

pub fn (p Parser) binding(name string) ? &rosie.Binding {
	if p.grammar.len > 0 {
		pkg := p.package_cache.get(p.grammar)?
		return pkg.get_(name)
	} else {
		pkg := p.package_by_varname(name)?
		return pkg.get_(name)
	}
}

[inline]
pub fn (p Parser) pattern(name string) ? &rosie.Pattern {
	return &p.binding(name)?.pattern
}

pub fn (parser Parser) pattern_str(name string) string {
	return if x := parser.pattern(name) {
		(*x).repr()
	} else {
		err.msg
	}
}

fn (mut parser Parser) add_charset_binding(name string, cs rosie.Charset) {
	cs_pat := rosie.CharsetPattern{ cs: cs }
	pat := rosie.Pattern{ elem: cs_pat }
	mut pkg := parser.package()
	pkg.bindings << rosie.Binding{ name: name, pattern: pat, package: pkg.name }
}
