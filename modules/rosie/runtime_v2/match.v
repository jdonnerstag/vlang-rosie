module runtime_v2

import rosie.runtime_v2 as rt

type CaptureFn = fn (capidx int, ref voidptr)

// Match Manage the matching process
struct Match {
	rplx Rplx					// The rplx data (compiled RPL)
	debug int					// 0 - no debugging; the larger, the more debug message

pub mut:
	package string = "main"		// Default package name, if not provided
	input string				// input data
	pos int

	captures []Capture			// The tree of captures
	stats Stats					// Collect some statistics

	matched bool
	recursives []string = []	// Bindings which are recursive
	skip_to_newline bool		// if true, skip until (inclusive) newline, at the end of every match process

	cap_notification CaptureFn	// Notify user about a new (positiv) capture
	fn_cap_ref voidptr
}

// new_match Create a new 'Match' object
pub fn new_match(rplx Rplx, debug int) Match {
	return Match {
		rplx: rplx,
		captures: []Capture{ cap: 100 },
		stats: new_stats(),
		matched: true,
		debug: debug,
	}
}

fn (m Match) get_capture_name(cap Capture) string {
	return m.rplx.symbols.get(cap.idx)
}

// has_match Determine whether any of the captured values has the name provided.
[inline]
pub fn (m Match) has_match(pname string) bool {
	return if _ := m.get_match_by(pname) { true } else { false }
}

// get_match_by Find a Capture by name
// Examples:
// m.get_match_by("*", "rpl_1_1.exp", "rpl_1_1.grammar-3.arg")? == "(x y)"
// m.get_match_by("rpl_1_1.exp", "rpl_1_1.grammar-3.arg")? == "(x y)"
// m.get_match_by("exp", "rpl_1_1.grammar-3.arg")? == "(x y)"
// m.get_match_by("exp", "grammar-3.arg")? == "(x y)"
// m.get_match_by("exp", "arg")? == "(x y)"
// m.get_match_by("*", "exp", "arg")? == "(x y)"
// m.get_match_by("exp.arg")? == "(x y)"
pub fn (m Match) get_match_by(path ...string) ?string {
	if path.len == 0 {
		return error("ERROR: get_match_by(): at least 1 path element must be provided")
	}

	mut stack := []string{}
	mut idx := -1
	mut level := 0
	for p in path {
		stack << p
		p2 := if p.contains(".") { p } else { m.package + "." + p }
		idx, level = m.get_all_match_by_(idx + 1, level, p, p2, true) or {
			if path.len == 1 && p.contains(".") {
				pelems := p.split(".")
				return m.get_match_by(...pelems)
			}
			return error("Capture with path $stack not found")
		}
	}

	cap := m.captures[idx]
	return m.input[cap.start_pos .. cap.end_pos]
}

fn (m Match) get_all_match_by_(start_idx int, start_level int, child1 string, child2 string, endswith bool) ? (int, int) {
	for i := start_idx; i < m.captures.len; i++ {
		cap := m.captures[i]
		if cap.level < start_level {
			break
		}

		if cap.matched {
			name := m.get_capture_name(cap)
			if name in [child1, child2] {
				return i, cap.level
			} else if endswith && name.ends_with("." + child1) {
				return i, cap.level
			}
		}
	}

	return none
}

pub fn (m Match) get_all_match_by(path ...string) ? []string {
	mut stack := []string{}
	mut idx := 0
	mut level := 0
	for p in path {
		stack << p
		p2 := if p.contains(".") { p } else { m.package + "." + p }
		idx, level = m.get_all_match_by_(idx, level, p, p2, false) or {
			return error("Capture with path $stack not found")
		}
		idx += 1
	}

	if idx > 0 { idx -= 1 }
	level -= 1
	mut p := stack.last()
	mut ar := []string{}
	for true {
		cap := m.captures[idx]
		ar << m.input[cap.start_pos .. cap.end_pos]

		p2 := if p.contains(".") { p } else { m.package + "." + p }
		idx, level = m.get_all_match_by_(idx + 1, level, p, p2, false) or {
			break
		}
	}
	return ar
}

// get_match Return the main, most outer, Capture
pub fn (m Match) get_match() ?string {
	if m.captures.len > 0 {
		cap := m.captures[0]
		if cap.matched {
			return m.input[cap.start_pos .. cap.end_pos]
		}
	}
	return error("No match")
}

// get_match_names Get the list of pattern (Capture) names found.
pub fn (m Match) get_match_names() []string {
	mut rtn := []string{}
	for cap in m.captures {
		if cap.matched {
			rtn << m.get_capture_name(cap)
		}
	}
	return rtn
}

fn (m Match) find_first_unmatched_parent(idx int) int {
	mut i := idx
	for i > 0 {
		i = m.captures[i].parent
		cap := m.captures[i]
		name := m.get_capture_name(cap)
		if cap.matched == false || name in m.recursives { return i }
	}
	return 0
}

fn (m Match) have_common_ancestor(capidx int, nodeidx int) bool {
	if capidx == nodeidx { return true }

	mut i := capidx
	for i > 0 {
		i = m.captures[i].parent
		if i == nodeidx { return true }
	}
	return false
}

fn (m Match) find_backref(name string, capidx int) ? &Capture {
	//eprintln(m.captures)
	for i := m.captures.len - 1; i >= 0; i-- {
		cap := &m.captures[i]
		if cap.matched && m.get_capture_name(cap) == name {
			//eprintln("\nFound backref by name: $i")
			idx := m.find_first_unmatched_parent(i)
			//eprintln("first unmatched parent: $idx, capidx: $capidx")
			if m.have_common_ancestor(capidx, idx) {
				//eprintln("has common ancestor: idx: $idx")
				return &m.captures[i]
			}
		}
	}

	return error("Backref not found: '$name'")
}

// replace Replace the main pattern match
fn (mut m Match) replace(repl string) string {
	if m.matched == false || m.captures.len == 0 {
		panic("Match failed. Nothing to replace")
	}

	cap := m.captures[0]
	return m.input[0 .. cap.start_pos] + repl + m.input[cap.end_pos .. ]
}

// replace Replace the pattern match identified by name
fn (mut m Match) replace_by(name string, repl string) ?string {
	if m.matched == false || m.captures.len == 0 {
		return error("Match failed. Nothing to replace")
	}

	for cap in m.captures {
		if m.get_capture_name(cap) == name {
			if cap.matched {
				return m.input[0 .. cap.start_pos] + repl + m.input[cap.end_pos .. ]
			}
			return error("Found pattern '$name' but it didn't match")
		}
	}
	return error("Did not find pattern with name '$name'")
}

pub fn (mut m Match) next_capture(from int, name string, any bool) ? int {
	xname := ".$name"
	for i in from .. m.captures.len {
		cap := m.captures[i]
		cap_name := m.get_capture_name(cap)
		if (any || cap.matched) && ((cap_name == name) || cap_name.ends_with(xname)) {
			return i
		}
	}

	return none
}

pub fn (mut m Match) child_capture(parent int, from int, name string) ? int {
	level := m.captures[parent].level

	for i in (from + 1) .. m.captures.len {
		cap := m.captures[i]
		if cap.level <= level { break }
		cap_name := m.get_capture_name(cap)
		if cap.matched && ((cap_name == name) || cap_name.ends_with(".$name")) {
			return i
		}
	}
	cap := m.captures[parent]
	mut len := cap.start_pos + 40
	if len > m.input.len { len = m.input.len }
	return error("RPL matcher: expected to find '$name': '${m.input[cap.start_pos .. len]}'")
}

pub struct CaptureFilter {
pub mut:
	captures []Capture
	pos int					// where to start (index) in the capture list
	last_level int			// level of last matched capture
pub:
	matched bool = true		// matched captures only
	level int				// Capture level must be >= level, else finish
}

// TODO V has a builtin filter() function, which obviously can not be replaced my own one.
pub fn (c []Capture) my_filter(args CaptureFilter) CaptureFilter {
	return CaptureFilter{ ...args, captures: c }
}

pub fn (c CaptureFilter) clone() CaptureFilter {
	return CaptureFilter{ ...c }
}

pub fn (c CaptureFilter) matched(matched bool) CaptureFilter {
	return CaptureFilter{ ...c, matched: matched }
}

pub fn (c CaptureFilter) level(level int) CaptureFilter {
	return CaptureFilter{ ...c, level: level }
}

pub fn (c CaptureFilter) pos(pos int) CaptureFilter {
	return CaptureFilter{ ...c, pos: pos }
}

pub fn (mut cf CaptureFilter) next() ? Capture {
	for cf.pos < cf.captures.len {
		cap := cf.captures[cf.pos]
		cf.pos ++

		if cap.level < cf.level {
			cf.pos = cf.captures.len
			break
		}

		if cap.matched {
			if cap.level <= (cf.last_level + 1) {
				cf.last_level = cap.level
				return cap
			}
		} else if cf.matched == false {
			return cap
		}
	}
	return error('')
}

// print_captures Nice for debugging
pub fn (m Match) print_captures(match_only bool) {
	mut first := true
	for cap in m.captures.my_filter(matched: match_only) {
		if first {
			println("\nCaptures:")
			first = false
		}

		name := m.get_capture_name(cap)
		if cap.matched {
			mut text := m.input[cap.start_pos .. cap.end_pos]
			if text.len > 40 { text = m.input[cap.start_pos .. cap.start_pos + 40] + " .." }
			text = text.replace("\n", r"\n").replace("\r", r"\r")
			elapsed := rt.thousand_grouping(cap.timer, `,`)
			println("${cap.level:2d} ${' '.repeat(cap.level)}$name: '$text' ($cap.start_pos, $cap.end_pos) $elapsed ns")
		} else {
			println("${cap.level:2d} ${' '.repeat(cap.level)}$name: <no match> ($cap.start_pos, -)")
		}
	}

	if first == false { println("") }
}
