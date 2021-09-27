module runtime_v2

import time

struct Stats {
pub mut:
  	match_time time.StopWatch
  	instr_count int				// number of vm instructions executed
  	backtrack_len int			// max len of backtrack stack used by vm
  	capture_len int    			// max len of capture list used by vm

	backtrack_push_count int	// How often btstack.push() was called
  	capture_push_count int    	// How often captures.push() was called.
}

fn new_stats() Stats {
	return Stats{ match_time: time.new_stopwatch() }
}