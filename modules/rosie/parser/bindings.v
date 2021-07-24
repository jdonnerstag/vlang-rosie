// ----------------------------------------------------------------------------
// (lexical) Scope and Binding related utils
// ----------------------------------------------------------------------------

module parser

import os
import math
import rosie.runtime as rt


struct Scope {
pub mut:
	bindings map[string]Binding		// name => expression
}

struct Binding {
pub:
	name string
	public bool			// if true, then the pattern is public
	alias bool			// if true, then the pattern is an alias
	pattern Pattern		// The pattern, the name is referring to
}

//[inline]
pub fn (b Binding) str() string {
	str := if b.public { "public" } else { "local" }
	return "Binding: $str $b.name=$b.pattern"
}

pub fn (parser Parser) scope(name string) int {
	if parser.scope_idx > 0 {
		if name in parser.scopes[parser.scope_idx].bindings {
			return parser.scope_idx
		}
	}
	return 0
}

//[inline]
pub fn (parser Parser) binding(name string) ? &Pattern {
	idx := parser.scope(name)
	if name in parser.scopes[idx].bindings {
		return &parser.scopes[idx].bindings[name].pattern
	}
	return error("Binding with name '$name' not found")
}

fn (mut parser Parser) parse_binding(scope_idx int) ? {
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

	if name in parser.scopes[scope_idx].bindings {
		return error("Pattern name already defined: '$name'")
	}

	//eprintln("Binding: parse binding for: local=$local, alias=$alias, name='$name'")
	root := GroupPattern{ word_boundary: true }
	pattern := parser.parse_compound_expression(root, 1)?
	parser.scopes[scope_idx].bindings[name] = Binding{
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
	parser.scopes[0].bindings[name] = b
}
