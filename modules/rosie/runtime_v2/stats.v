module runtime_v2

import time

struct Stats {
pub mut:
  	match_time time.StopWatch
  	instr_count int				// number of vm instructions executed
  	backtrack_len int			// max len of backtrack stack used by vm
  	capture_len int    			// max len of capture list used by vm
}

fn new_stats() Stats {
	return Stats{}
}