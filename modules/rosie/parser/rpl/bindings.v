// ----------------------------------------------------------------------------
// (lexical) Scope and Binding related utils
// ----------------------------------------------------------------------------

module rpl

import rosie


pub fn (p Parser) package() &rosie.Package {
	return p.package_cache.get(p.package) or {
		panic("Parser: package not found in cache?? name='$p.package'; cache=${p.package_cache.names()}")
	}
}

pub fn (p Parser) binding(name string) ? &rosie.Binding {
	if p.grammar.len > 0 {
		grammar_pkg := p.package_cache.get(p.grammar) or {
			panic("?? Should never happen. Grammar package not found: '$p.grammar'")
		}

		if x := grammar_pkg.get(p.package_cache, name) {
			return x
		}
	}
	return p.package().get(p.package_cache, name)
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
