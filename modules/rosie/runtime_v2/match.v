module runtime_v2

import rosie.runtime_v2 as rt

type CaptureFn = fn (capidx int)

// Match Manage the matching process
struct Match {
	rplx Rplx					// The rplx data (compiled RPL)
	debug int					// 0 - no debugging; the larger, the more debug message
	cap_notification CaptureFn	// Notify user about a new (positiv) capture

pub mut:
	package string = "main"		// Default package name, if not provided
  	input string				// input data
	pos int

	captures []Capture			// The tree of captures
	stats Stats					// Collect some statistics

  	matched bool
	recursives []string = []	// Bindings which are recursive
	skip_to_newline bool		// if true, skip until (inclusive) newline, at the end of every match process
}

// new_match Create a new 'Match' object
pub fn new_match(rplx Rplx, debug int) Match {
  	return Match {
		rplx: rplx,
		captures: []Capture{ cap: 10 },
		stats: new_stats(),
		matched: true,
		debug: debug,
	}
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
			if cap.name in [child1, child2] {
				return i, cap.level
			} else if endswith && cap.name.ends_with("." + child1) {
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
			rtn << cap.name
		}
	}
	return rtn
}

fn (mut m Match) find_first_unmatched_parent(idx int) int {
	mut i := idx
	for i > 0 {
		i = m.captures[i].parent
		cap := m.captures[i]
		if cap.matched == false || cap.name in m.recursives { return i }
	}
	return 0
}

fn (mut m Match) have_common_ancestor(capidx int, nodeidx int) bool {
	if capidx == nodeidx { return true }

	mut i := capidx
	for i > 0 {
		i = m.captures[i].parent
		if i == nodeidx { return true }
	}
	return false
}

fn (mut m Match) find_backref(name string, capidx int) ? &Capture {
	//eprintln(m.captures)
	for i := m.captures.len - 1; i >= 0; i-- {
		cap := &m.captures[i]
		if cap.matched && cap.name == name {
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
		if cap.name == name {
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
		if (any || cap.matched) && ((cap.name == name) || cap.name.ends_with(xname)) {
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
		if cap.matched && ((cap.name == name) || cap.name.ends_with(".$name")) {
			return i
		}
	}
	cap := m.captures[parent]
	mut len := cap.start_pos + 40
	if len > m.input.len { len = m.input.len }
	return error("RPL matcher: expected to find '$name': '${m.input[cap.start_pos .. len]}'")
}

// print_captures Nice for debugging
pub fn (m Match) print_captures(match_only bool) {
	mut first := true
    for c in m.captures {
		if c.matched {
			if first {
				println("\nCaptures:")
				first = false
			}
			text := m.input[c.start_pos .. c.end_pos]
			elapsed := rt.thousand_grouping(c.timer.elapsed(), `,`)
			println("${c.level:2d} ${' '.repeat(c.level)}$c.name: '$text' ($c.start_pos, $c.end_pos) $elapsed ns")
		} else if match_only == false {
			if first {
				println("\nCaptures:")
				first = false
			}
			println("${c.level:2d} ${' '.repeat(c.level)}$c.name: <no match> ($c.start_pos, -)")
		}
	}
	
	if first == false { println("") }
}
