// ----------------------------------------------------------------------------
// (lexical) Scope and Binding related utils
// ----------------------------------------------------------------------------

module rpl

import rosie


pub fn (p &Parser) package() &rosie.Package {
	if p.grammar_private == true && p.grammar.len > 0 {
		return p.package_cache.get(p.grammar) or {
			panic("Parser: package not found in cache?? name='$p.grammar'; cache=${p.package_cache.names()}")
		}
	}

	if p.package == "main" {
		return &p.main
	}

	return p.package_cache.get(p.package) or {
		panic("Parser: package not found in cache?? name='$p.package'; cache=${p.package_cache.names()}")
	}
}

pub fn (p Parser) binding(name string) ? &rosie.Binding {
	mut pkg := p.package()
	mut path := name.split(".")
	varname := path.pop()

	if name != "." {
		for e in path {
			fname := pkg.imports[e] or {
				return error("Binding not found: '$name'. Package '$pkg.name' has no '$e' import.")
			}
			pkg = p.package_cache.get(fname)?
		}
	}

	eprintln("name: '$name', varname: '$varname', pkg: '$pkg.name'")
	if rtn := pkg.get_(varname) {
		return rtn
	}

	eprintln("22 name: '$name', varname: '$varname', pkg: '$pkg.name', ($pkg.bindings.len)")
	for b in pkg.bindings { eprintln("b: $b.name") }

	for pkg.parent.len > 0 {
		pkg = p.package_cache.get(pkg.parent)?
		if rtn := pkg.get_(varname) {
			return rtn
		}
	}

	return error("Binding not found: '$name' in package='${p.package().name}' (file: '${p.package().fpath}')")
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
