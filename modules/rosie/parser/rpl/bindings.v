// ----------------------------------------------------------------------------
// (lexical) Scope and Binding related utils
// ----------------------------------------------------------------------------

module rpl

import rosie

// TODO remove
pub fn (p &Parser) package() &rosie.Package {
	return p.current
}

pub fn (p Parser) binding(name string) ? &rosie.Binding {
	return p.current.get(name)
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
