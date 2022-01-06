module rpl_3_0

import rosie
import rosie.expander

// expand Determine the binding by name and expand it's pattern (replace macros)
pub fn (mut p Parser) expand(name string, args rosie.FnExpandOptions) ? rosie.Pattern {
	mut e := expander.new_expander(main: p.main, debug: p.debug, unit_test: args.unit_test)
	return e.expand(name)
}
