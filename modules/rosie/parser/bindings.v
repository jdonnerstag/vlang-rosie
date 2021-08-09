// ----------------------------------------------------------------------------
// (lexical) Scope and Binding related utils
// ----------------------------------------------------------------------------

module parser

import rosie.runtime as rt


pub struct Binding {
pub:
	name string
	public bool			// if true, then the pattern is public
	alias bool			// if true, then the pattern is an alias
	pattern Pattern		// The pattern, the name is referring to
}

pub fn (b Binding) str() string {
	str := if b.public { "public" } else { "local" }
	return "Binding: $str $b.name=$b.pattern"
}

[inline]
pub fn (parser Parser) binding(name string) ? &Pattern {
	return parser.package.get_pattern(name)
}

//[inline]
pub fn (parser Parser) binding_(name string) ? Binding {
	return parser.package.get(name)
}

pub fn (parser Parser) binding_str(name string) string {
	return if x := parser.binding(name) {
		(*x).str()
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

	if name in parser.package.bindings {
		return error("Pattern name already defined: '$name' in '$parser.file'")
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

	parser.package.bindings[name] = Binding{
		public: !local,
		alias: alias,
		name: name,
		pattern: pattern
	}

	if parser.debug > 19 { eprintln("Binding: $name = ${parser.binding_str(name)}") }
}

fn (mut parser Parser) add_charset_binding(name string, cs rt.Charset) {
	cs_pat := CharsetPattern { cs: cs }
	pat := Pattern{ elem: cs_pat }
	b := Binding{ name: name, pattern: pat }
	parser.package.bindings[name] = b
}
