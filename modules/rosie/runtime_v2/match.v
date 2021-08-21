module runtime_v2

import time

type CaptureFn = fn (capidx int)

// Match Manage the matching process
struct Match {
	rplx Rplx					// The rplx data (compiled RPL)
	stop_watch time.StopWatch	// timestamp when started  	// TODO move to stats?
	debug int					// 0 - no debugging; the larger, the more debug message
	cap_notification CaptureFn	// Notify user about a new (positiv) capture

pub mut:
	package string = "main"		// Default package name, if not provided
  	input string		// input data
	pos int

	captures []Capture	// The tree of captures
	stats Stats			// Collect some statistics

  	matched bool
}

// new_match Create a new 'Match' object
pub fn new_match(rplx Rplx, debug int) Match {
  	return Match {
		rplx: rplx,
		captures: []Capture{ cap: 10 },
		stats: new_stats(),
		matched: true,
		debug: debug,
		stop_watch: time.new_stopwatch(auto_start: true),
	}
}

// has_more_instructions True if the program counter does not point beyond
// the end of the instructions
[inline]
fn (m Match) has_more_instructions(pc int) bool { return m.rplx.has_more_slots(pc) }

// instruction Given the program counter determine the Instruction
[inline]
fn (m Match) instruction(pc int) Slot { return m.rplx.slot(pc) }

// addr Many instruction are followed by a relative offset, which is used to determine the
// the byte code address
[inline]
fn (m Match) addr(pc int) int { return m.rplx.addr(pc) }

// eof True, of the all of the input has been consumed already.
[inline]
fn (m Match) eof(pos int) bool { return pos >= m.input.len }

// leftover A pattern may not match the complete input. Return what is left.
[inline]
fn (m Match) leftover() string { return m.input[m.pos ..] }

// cmp_char Given a byte at a specific position within the input data,
// compare it with the byte provided. Return false if already reached
// end of the input data.
[inline]
fn (m Match) cmp_char(pos int, ch byte) bool {
	return !m.eof(pos) && m.input[pos] == ch
}

// testchar Compare the byte at a specific position within the input data
// against the charset provided with the byte code instruction
[inline]
fn (m Match) testchar(pos int, pc int) bool {
	return !m.eof(pos) && testchar(m.input[pos], m.rplx.code, pc)
}

// has_match Determine whether any of the captured values has the name provided.
pub fn (m Match) has_match(pname string) bool {
	name := if pname.contains(".") { pname } else { m.package + "." + pname }
 	for cap in m.captures {
		if cap.matched && cap.name == name {
			return true
		}
	}
	return false
}

// get_match_by Find a Capture by name
fn (m Match) get_match_by(path ...string) ?string {
	mut stack := []string{}
	mut idx := 0
	mut level := 0
	for p in path {
		stack << p
		if idx > 0 { idx += 1 }
		idx, level = m.get_all_match_by_(idx, level, p) or {
			return error("Capture with path $stack not found")
		}
	}

	cap := m.captures[idx]
	return m.input[cap.start_pos .. cap.end_pos]
}

fn (m Match) get_all_match_by_(start_idx int, start_level int, child string) ? (int, int) {
	name := if child.contains(".") { child } else { m.package + "." + child }

	for i := start_idx; i < m.captures.len; i++ {
		cap := m.captures[i]
		if cap.level < start_level {
			break
		}

		if cap.matched && cap.name == name {
			return i, cap.level
		}
	}

	return none
}

fn (m Match) get_all_match_by(path ...string) ? []string {
	mut stack := []string{}
	mut idx := 0
	mut level := 0
	for p in path {
		stack << p
		idx, level = m.get_all_match_by_(idx, level, p) or {
			return error("Capture with path $stack not found")
		}
		idx += 1
	}

	level -= 1
	mut p := stack.last()
	mut ar := []string{}
	for true {
		cap := m.captures[idx]
		ar << m.input[cap.start_pos .. cap.end_pos]

		idx, level = m.get_all_match_by_(idx + 1, level, p) or {
			break
		}
	}
	return ar

}

// get_match Return the main, most outer, Capture
fn (m Match) get_match() ?string {
	if m.captures.len > 0 {
		cap := m.captures[0]
		if cap.matched {
			return m.input[cap.start_pos .. cap.end_pos]
		}
	}
	return error("No match")
}

// get_match_names Get the list of pattern (Capture) names found.
fn (m Match) get_match_names() []string {
	mut rtn := []string{}
	for cap in m.captures {
		if cap.matched {
			rtn << cap.name
		}
	}
	return rtn
}

[inline]
fn (mut m Match) add_capture(name string, pos int, level int, capidx int) int {
	m.captures << Capture{ name: name, matched: false, start_pos: pos, level: level, parent: capidx }
	if m.stats.capture_len < m.captures.len { m.stats.capture_len = m.captures.len }
	return m.captures.len - 1
}

[inline]
fn (mut m Match) close_capture(pos int, capidx int) int {
	mut cap := &m.captures[capidx]
	cap.end_pos = pos
	cap.matched = true
	/* if m.debug > 2 */{ eprint("\nCapture: ($cap.level) ${cap.name}='${m.input[cap.start_pos .. cap.end_pos]}'") }
	if !isnil(m.cap_notification) { m.cap_notification(capidx) }
	return cap.parent
}

[inline]
fn (mut m Match) add_btentry(mut btstack []BTEntry, entry BTEntry) {
	btstack << entry
	if btstack.len > 10000 { panic("RPL VM stack-overflow") }
	if m.stats.backtrack_len < btstack.len { m.stats.backtrack_len = btstack.len }
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
