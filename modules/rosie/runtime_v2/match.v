module runtime_v2

import rosie.runtime_v2 as rt

type CaptureFn = fn (capidx int, ref voidptr)

// Match Manage the matching process
struct Match {
pub:
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

fn (m Match) get_symbol(idx int) string {
	return m.rplx.symbols.get(idx)
}

fn (m Match) get_capture_name_idx(idx int) string {
	cap := m.captures[idx]
	return m.get_symbol(cap.idx)
}

fn (m Match) get_capture_input(cap rt.Capture) string {
	return m.input[cap.start_pos .. cap.end_pos]
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
			name := m.get_capture_name_idx(i)
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
			rtn << m.rplx.symbols.get(cap.idx)
		}
	}
	return rtn
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
		if m.rplx.symbols.get(cap.idx) == name {
			if cap.matched {
				return m.input[0 .. cap.start_pos] + repl + m.input[cap.end_pos .. ]
			}
			return error("Found pattern '$name' but it didn't match")
		}
	}
	return error("Did not find pattern with name '$name'")
}

// find Find a specific Capture by its pattern name
pub fn (m Match) find_cap(name string, matched bool) ?Capture {
	for cap in m.captures {
		if (matched || cap.matched) && m.rplx.symbols.get(cap.idx) == name {
			return cap
		}
	}
	return none
}

pub fn (mut m Match) next_capture(from int, name string, any bool) ? int {
	xname := ".$name"
	for i in from .. m.captures.len {
		cap := m.captures[i]
		cap_name := m.get_capture_name_idx(i)
		if (any || cap.matched) && ((cap_name == name) || cap_name.ends_with(xname)) {
			return i
		}
	}

	return none
}

pub fn (mut m Match) child_capture(parent int, from int, name_idx int) ? int {
	level := m.captures[parent].level

	for i in (from + 1) .. m.captures.len {
		cap := m.captures[i]
		if cap.level <= level {
			break
		}

		if cap.matched && cap.idx == name_idx {
			return i
		}
	}

	name := m.rplx.symbols.get(name_idx)
	return error("RPL matcher: expected to find '$name' starting from: $from")
}

[params]
pub struct CaptureFilter {
pub mut:
	captures []Capture
	pos int					// where to start (index) in the capture list
	count int
pub:
	any bool 				// if false, then matched captures only
	level int				// Capture level must be >= level, else finish
}

// TODO V has a builtin filter() function, which obviously can not be replaced my own one.
pub fn (c []Capture) my_filter(args CaptureFilter) CaptureFilter {
	return CaptureFilter{ ...args, captures: c }
}

pub fn (c CaptureFilter) clone() CaptureFilter {
	return CaptureFilter{ ...c }
}

pub fn (c CaptureFilter) any(any bool) CaptureFilter {
	return CaptureFilter{ ...c, any: any }
}

pub fn (c CaptureFilter) level(level int) CaptureFilter {
	return CaptureFilter{ ...c, level: level }
}

pub fn (c CaptureFilter) pos(pos int) CaptureFilter {
	return CaptureFilter{ ...c, pos: pos }
}

pub fn (c CaptureFilter) last() int {
	return c.pos - 1
}

pub fn (mut cf CaptureFilter) next() ? Capture {
	for cf.pos < cf.captures.len {
		cap := cf.captures[cf.pos]
		cf.pos ++

		if cap.level < cf.level {
			break
		}

		if cap.level == cf.level {
			if cf.count != 0 { break }
			cf.count ++
		}

		if cf.any {
			return cap
		}

		if cap.matched {
			mut idx := cap.parent
			for cf.captures[idx].matched {
				if idx == 0 {
					return cap
				}
				idx = cf.captures[idx].parent
			}
		}
	}

	cf.pos = cf.captures.len
	return error('')
}

// print_captures Nice for debugging
pub fn (m Match) print_captures(any bool) {
	mut first := true
	for cap in m.captures.my_filter(any: any) {
		if first {
			println("\nCaptures:")
			first = false
		}

		println(m.capture_str(cap))
	}

	if first == false {
		println("")
	}
}

pub fn (m Match) capture_str(cap rt.Capture) string {
	name := m.get_symbol(cap.idx)
	if cap.matched {
		mut text := m.input[cap.start_pos .. cap.end_pos]
		if text.len > 60 { text = text[.. 60] + ".. "}
		text = text.replace("\n", r"\n").replace("\r", r"\r")
		elapsed := rt.thousand_grouping(cap.timer, `,`)
		return "${cap.level:2d} ${' '.repeat(cap.level)}$name: '$text' ($cap.start_pos, $cap.end_pos) $elapsed ns"
	} else {
		return "${cap.level:2d} ${' '.repeat(cap.level)}$name: <no match> ($cap.start_pos, -)"
	}
}

pub fn (m Match) print_capture_level(pos int) {
	level := m.captures[pos].level

	mut count := 0
	mut iter := m.captures.my_filter(pos: pos, level: level, any: false)
	for {
		cap := iter.next() or { break }
		println("pos: $pos - $iter.pos, ${m.capture_str(cap)}")
		count ++
		if count > 200 {
			println(" ..stopped after 200 captures")
			break
		}
	}
}

pub fn (m Match) capture_next_child_match(pos int, plevel int) ? int {
	level := if plevel < 0 { m.captures[pos].level - 1 } else { plevel }
	mut iter := m.captures.my_filter(any: false, pos: pos, level: level)
	iter.next() or { return error('No matching child capture found: start: $pos, level: $level') }
	return iter.pos - 1
}

pub fn (m Match) capture_next_sibling_match(pos int) ? int {
	level := m.captures[pos].level
	for idx := pos + 1; idx < m.captures.len; idx ++ {
		cap := m.captures[idx]
		if cap.matched && cap.level == level {
			return idx
		} else if cap.level < level {
			break
		}
	}
	return error("")
}
