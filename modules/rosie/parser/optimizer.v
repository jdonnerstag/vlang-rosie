// ----------------------------------------------------------------------------
// Analyze the AST of a single pattern and optimize it
// ----------------------------------------------------------------------------

module parser

// optimize Some optimization on AST level
// A word of caution: Always measure the effect of an optimization. Many times,
// the effect is minimal and hardly it. This is also true for these optimizations.
// They have not been performance tested (neither end-to-end performance nor runtime
// improvements). This also why they are disabled for now.
//
// 1) level 1: Eliminate groups that that have no elements
// 2) level 1: Eliminate groups that contain only 1 element
// 3) level 1: Eliminate groups which the user added for readability, e.g. "(a b) c" => "a b c"
// 4) level 1: Replace single char charsets with a literal => E.g. [a] => "a"
// 5) level 2: Combine literals, e.g.  {"a" "b"} is the same as "ab"
fn (mut parser Parser) optimize(pattern Pattern, count int) (Pattern, int) {

	if pattern.elem is GroupPattern {
		return parser.optimize_group(pattern, count)
	} else if pattern.elem is CharsetPattern {
		return parser.optimize_charset(pattern, count)
	}
	return pattern, count
}

fn (mut parser Parser) optimize_group(pattern Pattern, count int) (Pattern, int) {
	if pattern.elem is GroupPattern {
		// 2) Eliminate groups that contain only 1 element
		if pattern.elem.ar.len == 1 {
			return pattern.elem.ar[0], count + 1
		}

		mut cnt := count
		mut ar := []Pattern{}

		for e in pattern.elem.ar {
			pat, cnt2 := parser.optimize(e, cnt)
			cnt = cnt2

			// 1) Eliminate groups that that have no elements
			if pat.elem is GroupPattern {
				if pat.elem.ar.len == 0 {
					cnt += 1
					continue
				}
			}
			ar << pat
		}

		mut pat := pattern
		if mut pat.elem is GroupPattern { pat.elem.ar = ar }
		return pat, cnt
	}

	return pattern, count
}

fn (mut parser Parser) optimize_charset(pattern Pattern, count int) (Pattern, int) {

	if pattern.elem is CharsetPattern {
		mut pat := pattern
		cnt, ch := pattern.elem.cs.count()
		if cnt == 1 {
			// 4) Replace single char charsets with a literal => E.g. [a] => "a"
			pat.elem = LiteralPattern{ text: ch.ascii_str() }
		} else if cnt == C.UCHAR_MAX {
			pat.elem = AnyPattern{}
		} else if cnt == 0 {
			// This will never match anything ?!
			// If predicate is "not" than it will match everything
			// What is predicate is look-ahead or look-behind. Does it then have a meaning?
		}
		return pat, count + 1
	}
	return pattern, count
}
