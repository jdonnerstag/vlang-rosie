// ----------------------------------------------------------------------------
// Analyze the AST of a single pattern and optimize it
// ----------------------------------------------------------------------------

module core_0

import rosie.parser.common as core


// optimize Some optimization on AST level
// A word of caution: Always measure the effect of an optimization. Many times,
// the effect is minimal and hardly it. This is also true for these optimizations.
// They have not been performance tested (neither end-to-end performance nor runtime
// improvements). This also why they are disabled for now.
//
// 1) level 1: Eliminate groups that that have no elements
// 2) level 1: Eliminate groups that contain only 1 element and have no multipliers and word_boundary
// 3) level 1: Eliminate groups which the user added for readability, e.g. "(a b) c" => "a b c"
// 4) level 1: Replace single char charsets with a literal => E.g. [a] => "a"
// 5) level 2: Combine literals, e.g.  {"a" "b"} is the same as "ab"
fn (mut parser Parser) optimize(pattern core.Pattern, count int) (core.Pattern, int) {

	if pattern.elem is core.GroupPattern {
		return parser.optimize_group(pattern, count)
	} else if pattern.elem is core.CharsetPattern {
		return parser.optimize_charset(pattern, count)
	}
	return pattern, count
}

fn (mut parser Parser) optimize_group(pattern core.Pattern, count int) (core.Pattern, int) {
	if pattern.elem is core.GroupPattern {
		// 2) Eliminate groups that contain only 1 element
		if pattern.elem.ar.len == 1 {
			return pattern.elem.ar[0], count + 1
		}

		mut cnt := count
		mut ar := []core.Pattern{}

		for e in pattern.elem.ar {
			pat, cnt2 := parser.optimize(e, cnt)
			cnt = cnt2

			// 1) Eliminate groups that that have no elements
			if pat.elem is core.GroupPattern {
				if pat.elem.ar.len == 0 {
					cnt += 1
					continue
				}
			}
			ar << pat
		}

		mut pat := pattern
		if mut pat.elem is core.GroupPattern { pat.elem.ar = ar }
		return pat, cnt
	}

	return pattern, count
}

fn (mut parser Parser) optimize_charset(pattern core.Pattern, count int) (core.Pattern, int) {

	if pattern.elem is core.CharsetPattern {
		mut pat := pattern
		cnt, ch := pattern.elem.cs.count()
		if cnt == 1 {
			// 4) Replace single char charsets with a literal => E.g. [a] => "a"
			pat.elem = core.LiteralPattern{ text: ch.ascii_str() }
		} else if cnt == 0 {
			// This will never match anything ?!
			// If predicate is "not" than it will match everything
			// What is predicate is look-ahead or look-behind. Does it then have a meaning?
		}
		return pat, count + 1
	}
	return pattern, count
}
