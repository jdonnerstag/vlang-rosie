module rpl

import rosie
import rosie.expander

// expand Determine the binding by name and expand it's pattern (replace macros)
pub fn (mut p Parser) expand(name string) ? rosie.Pattern {
	mut e := expander.new_expander(main: p.main, debug: p.debug)
	return e.expand(name)
}
