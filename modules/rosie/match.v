module rosie

import time

struct Match {
	rplx Rplx			// The rplx data (compiled RPL)
	encoder Encoder		// TODO ?? Not quite sure
	stop_watch time.StopWatch	// timestamp when started  	// TODO move to stats?

pub mut:
  	data Buffer			// input data incl. cursor for current position  // TODO is there really value in using Buffer over string and pos separately ?!?
	captures []Capture	// The list of current captures
	capstats []CapState	// The list of current captures
	stats Stats			// Collect some statistics

  	matched bool		// if false then ignore data field. // TODO and what is the meaning?
  	abend bool	  		// meaningful only if matched == true	// TODO and what is the meaning?

	debug int			// 0 - no debugging; the larger, the more debug message
}

fn new_match(rplx Rplx, encoder Encoder) Match {
  	return Match { 
		rplx: rplx,
		encoder: encoder,
		captures: []Capture{ cap: 30 },
		stats: new_stats(),
		abend: false,
		matched: false,
		stop_watch: time.new_stopwatch(auto_start: true),
	}
}

[inline]
fn (m Match) leftover() int { return m.data.leftover() }

[inline]
fn (m Match) ktable() Ktable { return m.rplx.ktable }

// TODO Move to Instructions
[inline]
fn (m Match) eof(pc int) bool { return pc >= m.rplx.code.len }

// TODO Move to Instructions
[inline]
fn (m Match) instruction(pc int) Instruction { return m.rplx.code[pc] }

// TODO Move to Instructions
[inline]
fn (m Match) get_charset(pc int) []int { 
	// TODO awkward right now
	// return []int(m.rplx.code[pc .. (pc + charset_inst_size)]) 
	return [int(m.rplx.code[pc].val), m.rplx.code[pc+1].val, m.rplx.code[pc+2].val, m.rplx.code[pc+3].val]
}

// TODO Move to Instructions
[inline]
fn (m Match) addr(pc int) int { return m.instruction(pc + 1).val }
