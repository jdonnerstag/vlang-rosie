// ----------------------------------------------------------------------------
// (lexical) Scope and Binding related utils
// ----------------------------------------------------------------------------

module core_0

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

pub fn (p Parser) pattern_str(name string) string {
	return if x := p.pattern(name) {
		(*x).repr()
	} else {
		err.msg
	}
}

fn (mut parser Parser) parse_binding() ? {
	if parser.debug > 98 {
		eprintln(">> ${@FN}: '${parser.debug_input()}', tok=$parser.last_token, eof=${parser.is_eof()} ${' '.repeat(40)}")
		defer { eprintln("<< ${@FN}: tok=$parser.last_token, eof=${parser.is_eof()}") }
	}

	mut t := &parser.tokenizer

	builtin_kw := parser.peek_text(rosie.builtin)
	func := parser.peek_text("func")
	local := parser.peek_text("local")
	alias := parser.peek_text("alias")
	mut name := "*"

	parser.last_token()?
	if parser.is_assignment() {
		name = t.get_text()
		parser.next_token()?
		parser.next_token()?
	}

	// Detect duplicate variable names
	if builtin_kw == false {
		if parser.package().has_binding(name) {
			mut fname := parser.package().fpath
			if fname.len == 0 { fname = "<unknown>" }
			return error("Pattern name already defined: '$name' in file '$fname'")
		}
	} else {
		// Remove binding with 'name' from builtin package
		mut pkg := parser.package_cache.get(rosie.builtin)?
		idx := pkg.get_idx(name)
		if idx >= 0 {
			pkg.bindings.delete(idx)
		}
	}

	//eprintln("Binding: parse binding for: local=$local, alias=$alias, name='$name'")
	assert parser.parents.len == 0
	parser.parents << rosie.Pattern{ elem: rosie.GroupPattern{ word_boundary: true } }
	parser.parse_compound_expression(1)?
	mut root := parser.parents.pop()

	for {
		if root.is_standard() {
			elem := root.elem
			if elem is rosie.GroupPattern {
				if elem.ar.len == 1 {
					root = elem.ar[0]
					continue
				}
			} else if elem is rosie.DisjunctionPattern {
				if elem.negative == false && elem.ar.len == 1 {
					root = elem.ar[0]
					continue
				}
			}
		}
		break
	}

	mut elem := root.elem
	if mut elem is rosie.GroupPattern {
		if elem.word_boundary && elem.ar.len > 1 {
			elem.word_boundary = false
			root = rosie.Pattern{ elem: rosie.MacroPattern{ name: "tok", pat: root } }
		}
	}

	mut pkg := parser.package()
	if builtin_kw {
		pkg = parser.package_cache.get(rosie.builtin)?
	}

	pkg.bindings << rosie.Binding{
		public: !local,
		alias: alias,
		func: func,
		name: name,
		pattern: root,
		package: parser.package,
		grammar: parser.grammar,
	}

	if parser.debug > 19 { eprintln("Binding: ${parser.binding(name)?.repr()}") }
}

fn (mut parser Parser) add_charset_binding(name string, cs rosie.Charset) {
	cs_pat := rosie.CharsetPattern{ cs: cs }
	pat := rosie.Pattern{ elem: cs_pat }
	mut pkg := parser.package()
	pkg.bindings << rosie.Binding{ name: name, pattern: pat, package: pkg.name }
}
