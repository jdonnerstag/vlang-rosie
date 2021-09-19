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
	package string 	 	// The package containing the binding
	grammar string		// The grammar context, if any
pub mut:
	pattern Pattern		// The pattern, the name is referring to
	func bool			// if true, then compile it into a function (superseding alias, if set)
	recursive bool		// This binding is flagged as recursive
}

pub fn (b Binding) repr() string {
	mut str := if b.public { "public " } else { "local " }
	str += if b.alias { "alias " } else { "" }
	str += if b.func { "func " } else { "" }
	str += if b.recursive { "recursive " } else { "" }
	str = "Binding: ${str}'${b.package}.${b.name}' = ${b.pattern.repr()}"
	if b.grammar.len > 0 { str += "   (grammar: '$b.grammar')"}
	return str
}

pub fn (b Binding) full_name() string {
	return b.package + "." + b.name
}

pub fn (p Parser) package() &Package {
	return p.package_cache.get(p.package) or {
		panic("Parser: package not found in cache?? name='$p.package'; cache=${p.package_cache.names()}")
	}
}

pub fn (p Parser) binding(name string) ? &Binding {
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

	// Detect duplicate variable names
	if parser.package().has_binding(name) {
		fname := if parser.file.len == 0 { "<unknown>" } else { parser.file }
		return error("Pattern name already defined: '$name' in file '$fname'")
	}

	//eprintln("Binding: parse binding for: local=$local, alias=$alias, name='$name'")
	// TODO obvioulsy there is a copy() involved
	assert parser.parents.len == 0
	parser.parents << Pattern{ elem: GroupPattern{ word_boundary: true } }
	parser.parse_compound_expression(1)?

	mut root := parser.parents.pop()

	for {
		if root.is_standard() {
			elem := root.elem
			if elem is GroupPattern {
				if elem.ar.len == 1 {
					root = elem.ar[0]
					continue
				}
			} else if elem is DisjunctionPattern {
				if elem.negative == false && elem.ar.len == 1 {
					root = elem.ar[0]
					continue
				}
			}
		}
		break
	}

	elem := root.elem
	if elem is GroupPattern {
		if elem.word_boundary && elem.ar.len > 1 {
			root = Pattern{ elem: MacroPattern{ name: "tok", pat: root } }
		}
	}

	mut pkg := parser.package()
	pkg.bindings << Binding{
		public: !local,
		alias: alias,
		name: name,
		pattern: root,
		package: parser.package,
		grammar: parser.grammar,
	}

	if parser.debug > 19 { eprintln("Binding: ${parser.binding(name)?.repr()}") }
}

fn (mut parser Parser) add_charset_binding(name string, cs rt.Charset) {
	cs_pat := CharsetPattern { cs: cs }
	pat := Pattern{ elem: cs_pat }
	mut pkg := parser.package()
	pkg.bindings << Binding{ name: name, pattern: pat, package: pkg.name }
}
