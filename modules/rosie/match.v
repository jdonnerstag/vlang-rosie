module rosie

import time

struct Match {
	rplx Rplx					// The rplx data (compiled RPL)
	stop_watch time.StopWatch	// timestamp when started  	// TODO move to stats?
	debug int					// 0 - no debugging; the larger, the more debug message

pub mut:
  	input string		// input data 
	pos int

	captures []Capture	// The tree of captures
	stats Stats			// Collect some statistics

  	matched bool		
}

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

[inline]
fn (m Match) ktable() Ktable { return m.rplx.ktable }

[inline]
fn (m Match) has_more_instructions(pc int) bool { return m.rplx.has_more_instructions(pc) }

[inline]
fn (m Match) instruction(pc int) Instruction { return m.rplx.instruction(pc) }

[inline]
fn (m Match) addr(pc int) int { return m.rplx.addr(pc) }

[inline]
fn (m Match) eof(pos int) bool { return pos >= m.input.len }

// TODO Change to return the remaining string
[inline]
fn (m Match) leftover() string { return m.input[m.pos ..] }

[inline]
fn (m Match) cmp_char(pos int, ch byte) bool { 
	return !m.eof(pos) && m.input[pos] == ch 
}

[inline]
fn (m Match) testchar(pos int, pc int) bool {
	return !m.eof(pos) && testchar(m.input[pos], m.rplx.code, pc)
}

[inline]
fn (m Match) has_match(name string) bool {
    return if _ := m.captures.find(name, m.input) { true } else { false }
}

[inline]
fn (m Match) get_match_by(name string) ?string { 
	return m.captures.find(name, m.input) 
}

[inline]
fn (m Match) get_match() ?string { 
	if m.captures.len > 0 {
		cap := m.captures[0]
		if cap.matched { 
			return m.input[cap.start_pos .. cap.end_pos] 
		}
	}
	return error("No match")
}

fn (m Match) get_match_names() []string {
	mut rtn := []string{}
	for cap in m.captures {
		if cap.matched {
			rtn << cap.name
		}
	}
	return rtn	
}
