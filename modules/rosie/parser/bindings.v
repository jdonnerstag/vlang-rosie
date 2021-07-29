// ----------------------------------------------------------------------------
// (lexical) Scope and Binding related utils
// ----------------------------------------------------------------------------

module parser

import rosie.runtime as rt


struct Scope {
pub mut:
	bindings map[string]Binding		// name => expression
}

struct Binding {
pub:
	name string
	package string		// The package or grammar containing the definition
	public bool			// if true, then the pattern is public
	alias bool			// if true, then the pattern is an alias
	pattern Pattern		// The pattern, the name is referring to
}

//[inline]
pub fn (b Binding) str() string {
	str := if b.public { "public" } else { "local" }
	return "Binding: $str $b.name=$b.pattern"
}

pub fn (parser Parser) scope(name string) string {
	if parser.package_name.len > 0 {
		if name in parser.packages[parser.package_name].bindings {
			return parser.package_name
		}
	}
	return ""
}

//[inline]
pub fn (parser Parser) binding(name string) ? &Pattern {
	idx := parser.scope(name)
	if name in parser.packages[idx].bindings {
		return &parser.packages[idx].bindings[name].pattern
	}
	return error("Binding with name '$name' not found")
}

//[inline]
pub fn (parser Parser) binding_(name string) ? Binding {
	idx := parser.scope(name)
	if name in parser.packages[idx].bindings {
		return parser.packages[idx].bindings[name]
	}
	return error("Binding with name '$name' not found")
}

pub fn (parser Parser) binding_str(name string) string {
	return if x := parser.binding(name) {
		(*x).str()
	} else {
		err.msg
	}
}

pub fn (parser Parser) print(name string) {
	eprintln(parser.binding_str(name))
}

fn (mut parser Parser) parse_binding(package_name string) ? {
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

	if name in parser.packages[package_name].bindings {
		return error("Pattern name already defined: '$name'")
	}

	//eprintln("Binding: parse binding for: local=$local, alias=$alias, name='$name'")
	root := GroupPattern{ word_boundary: true }
	pattern := parser.parse_compound_expression(root, 1)?
	parser.packages[package_name].bindings[name] = Binding{
		public: !local,
		alias: alias,
		name: name,
		pattern: pattern
	}

	if parser.debug > 9 { parser.print(name) }
}

fn (mut parser Parser) add_charset_binding(name string, cs rt.Charset) {
	cs_pat := CharsetPattern { cs: cs }
	pat := Pattern{ elem: cs_pat }
	b := Binding{ name: name, pattern: pat }
	parser.packages["main"].bindings[name] = b
}
