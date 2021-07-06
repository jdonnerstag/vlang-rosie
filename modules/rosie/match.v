module rosie

import time

struct Match {
	rplx Rplx			// The rplx data (compiled RPL)
	stop_watch time.StopWatch	// timestamp when started  	// TODO move to stats?
	debug int			// 0 - no debugging; the larger, the more debug message

pub mut:
  	input string		// input data 
	pos int

	captures []Capture	// The list captures
	stats Stats			// Collect some statistics

  	matched bool		// 
}

pub fn new_match(rplx Rplx, debug int) Match {
  	return Match {
		rplx: rplx,
		captures: []Capture{},
		stats: new_stats(),
		matched: true,
		debug: debug,
		stop_watch: time.new_stopwatch(auto_start: true),
	}
}

[inline]
fn (m Match) leftover(pos int) int { return m.input.len - pos }

[inline]
fn (m Match) ktable() Ktable { return m.rplx.ktable }

// TODO Move to Instructions
[inline]
fn (m Match) has_more_instructions(pc int) bool { return pc < m.rplx.code.len }

// TODO Move to Instructions
[inline]
fn (m Match) instruction(pc int) Instruction { return m.rplx.code[pc] }

[inline]
fn (m Match) addr(pc int) int { return pc + m.instruction(pc + 1).val }

[inline]
fn (m Match) eof(pos int) bool { return pos >= m.input.len }

[inline]
fn (m Match) cmp_char(pos int, ch byte) bool { 
	return !m.eof(pos) && m.input[pos] == ch 
}

[inline]
fn (m Match) testchar(pos int, pc int) bool {
	return !m.eof(pos) && testchar(m.input[pos], m.rplx.code, pc)
}
