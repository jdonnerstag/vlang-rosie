module rpl

import rosie
import rosie.expander


[params]
pub struct FnExpandOptions {
	unit_test bool
}

// expand Determine the binding by name and expand it's pattern (replace macros)
pub fn (mut p Parser) expand(name string, args FnExpandOptions) ? rosie.Pattern {
	mut e := expander.new_expander(main: p.main, debug: p.debug, unit_test: args.unit_test)
	return e.expand(name)
}
