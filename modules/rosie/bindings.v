// ----------------------------------------------------------------------------
// (lexical) Scope and Binding related utils
// ----------------------------------------------------------------------------

module rosie


pub struct Binding {
pub mut:
	name string

	public bool			// if true, then the pattern is public
	alias bool			// if true, then the pattern is an alias
	func bool			// if true, then compile it into a function (superseding alias, if set)
	recursive bool		// This binding is allowed to be recursive
	expanded bool		// Indicating that the binding has been "expanded" already

	package string 	 	// The package owning the binding	// TODO Is this needed?
	grammar string		// public grammar bindings can also "see" bindings from within the grammar	// TODO should this be a Package ref?

	pattern Pattern		// The pattern, the name is referring to
}

pub fn (b Binding) repr() string {
	mut str := if b.public { "public " } else { "local " }
	str += if b.alias { "alias " } else { "" }
	str += if b.func { "func " } else { "" }
	str += if b.recursive { "recursive " } else { "" }
	mut name := b.name
	if b.package.len > 0 { name = b.package + "." + name }
	str = "Binding: ${str}'${name}' = ${b.pattern.repr()}"
	if b.grammar.len > 0 { str += "   (grammar: '$b.grammar')"}
	return str
}

pub fn (b Binding) full_name() string {
	return b.package + "." + b.name
}
