module vlang

import rosie


struct StringBE {
pub:
	pat rosie.Pattern
	text string
}

fn (cb StringBE) compile(mut c Compiler) ? string {
	//eprintln("RPL vlang compiler: StringBE: compile '$cb.text'")
	// TODO escape cb.text

	cmd := "m.match_literal('${cb.text}')"
	if cb.pat.predicate == .na && cb.pat.min == 1 && cb.pat.max == 1 {
		return cmd
	}

	fn_name := c.pattern_fn_name()
	mut fn_str := c.open_pattern_fn(fn_name, cb.pat.repr())
	fn_str += c.gen_code(cb.pat, cmd)
	c.close_pattern_fn(fn_name, fn_str)

	return "m.${fn_name}()"
}
