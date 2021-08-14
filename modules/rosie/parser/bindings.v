// ----------------------------------------------------------------------------
// (lexical) Scope and Binding related utils
// ----------------------------------------------------------------------------

module parser

import rosie.runtime_v2 as rt


pub struct Binding {
pub:
	name string
	public bool			// if true, then the pattern is public
	alias bool			// if true, then the pattern is an alias
	func bool			// if true, then compile it into a function
	pattern Pattern		// The pattern, the name is referring to
	fpath string 	 	// The package (fpath; index into package cache) containing the binding
}

pub fn (b Binding) repr() string {
	str := if b.public { "public" } else { "local" }
	return "Binding: $str $b.name=$b.pattern"
}

pub fn (p Parser) package() &Package {
	return p.package_cache.get(p.package) or {
		panic("Parser default package not found in cache?? name='$p.package'; cache=${p.package_cache.names()}")
	}
}

[inline]
pub fn (p Parser) binding(name string) ? &Binding {
	return p.package().get(p.package_cache, name)
}

[inline]
pub fn (p Parser) pattern(name string) ? &Pattern {
	return &p.binding(name)?.pattern
}

pub fn (parser Parser) pattern_str(name string) string {
	return if x := parser.pattern(name) {
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

	local := parser.peek_text("local")
	alias := parser.peek_text("alias")
	mut name := "*"

	parser.last_token()?
	if parser.is_assignment() {
		name = t.get_text()
		parser.next_token()?
		parser.next_token()?
	}

	if _ := parser.package().get_(name) {
		return error("Pattern name already defined: '$name' in file '$parser.file'")
	}

	//eprintln("Binding: parse binding for: local=$local, alias=$alias, name='$name'")
	// TODO obvioulsy there is a copy() involved
	mut root := GroupPattern{ word_boundary: true }
	parser.parse_compound_expression(mut root, 1)?
	pattern := if root.ar.len == 1 {
		root.ar[0]
	} else {
		Pattern{ elem: root }
	}

	mut pkg := parser.package()
	pkg.bindings << Binding{
		public: !local,
		alias: alias,
		name: name,
		pattern: pattern,
		fpath: pkg.fpath,
	}

	if parser.debug > 19 { eprintln("Binding: $name = ${parser.pattern_str(name)}") }
}

fn (mut parser Parser) add_charset_binding(name string, cs rt.Charset) {
	cs_pat := CharsetPattern { cs: cs }
	pat := Pattern{ elem: cs_pat }
	mut pkg := parser.package()
	pkg.bindings << Binding{ name: name, pattern: pat, fpath: pkg.fpath }
}
