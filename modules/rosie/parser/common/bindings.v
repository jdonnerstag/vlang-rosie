// ----------------------------------------------------------------------------
// (lexical) Scope and Binding related utils
// ----------------------------------------------------------------------------

module common

import rosie.runtime_v2 as rt


pub struct Binding {
pub mut:
	name string
	public bool			// if true, then the pattern is public
	alias bool			// if true, then the pattern is an alias
	package string 	 	// The package containing the binding
	grammar string		// The grammar context, if any
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
