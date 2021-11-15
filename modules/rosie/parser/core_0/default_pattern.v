module core_0

import rosie.parser.common as core
import rosie.runtime_v2 as rt

const (
	ascii = core.new_charset_pattern("\000-\177")

	// The macro will execute a "dot" byte code instruction, which makes the
	// byte code much smaller, and hopefully the dot matching process significantly
	// faster as well.
	//utf8_pat = init_utf8_pat(ascii)
	utf8_pat = core.Pattern{ elem: core.MacroPattern{ name: "dot_instr" } }

	// The macro will execute a "word_boundary" byte code instruction, which makes the
	// byte code much smaller, and hopefully the word_boundary matching process significantly
	// faster as well.
	//word_boundary_pat = init_word_boundary_pat()
	word_boundary_pat = core.Pattern{ elem: core.MacroPattern{ name: "word_boundary" } }
)

fn init_utf8_pat(ascii core.Pattern) core.Pattern {
	b1_lead := core.ascii
	b2_lead := core.new_charset_pattern("\300-\337")
	b3_lead := core.new_charset_pattern("\340-\357")
	b4_lead := core.new_charset_pattern("\360-\367")
	c_byte := core.new_charset_pattern("\200-\277")

	b2 := core.new_sequence_pattern(false, [b2_lead, c_byte])
	b3 := core.new_sequence_pattern(false, [b3_lead, c_byte, c_byte])
	b4 := core.new_sequence_pattern(false, [b4_lead, c_byte, c_byte, c_byte])

	return core.Pattern{ elem: core.DisjunctionPattern{ negative: false, ar: [b1_lead, b2, b3, b4] } }
}

fn init_word_boundary_pat() core.Pattern {
	// The boundary symbol, ~, is an ordered choice of:
	//   [:space:]+                   consume all whitespace
	//   { >word_char !<word_char }   looking at a word char, and back at non-word char
	//   >[:punct:] / <[:punct:]      looking at punctuation, or back at punctuation
	//   { <[:space:] ![:space:] }    looking back at space, but not ahead at space
	//   $                            looking at end of input
	//   ^                            looking back at start of input
	// where word_char is the ASCII-only pattern [[A-Z][a-z][0-9]]

	space := core.Pattern{ min: 1, max: -1, elem: core.CharsetPattern{ cs: rt.known_charsets["space"] } }
	word_char := core.Pattern{ elem: core.CharsetPattern{ cs: rt.cs_alnum } }
	punct := core.Pattern{ elem: core.CharsetPattern{ cs: rt.known_charsets["punct"] } }

	o1 := space
	o2 := core.new_sequence_pattern(false, [
		core.Pattern{ ...word_char, predicate: .look_ahead },
		core.Pattern{ ...word_char, predicate: .negative_look_behind },
	])
	o3 := core.new_choice_pattern(false, [
		core.Pattern{ ...punct, predicate: .look_ahead },
		core.Pattern{ ...punct, predicate: .look_behind },
	])
	o4 := core.new_sequence_pattern(false, [
		core.Pattern{ ...space, predicate: .look_behind },
		core.Pattern{ ...space, predicate: .negative_look_ahead },
	])
	o5 := core.Pattern{ min: 1, max: 1, elem: core.EofPattern{ eof: true } }
	o6 := core.Pattern{ min: 1, max: 1, elem: core.EofPattern{ eof: false } }

	return core.Pattern{ elem: core.DisjunctionPattern{ negative: false, ar: [o1, o2, o3, o4, o5, o6] } }
}
