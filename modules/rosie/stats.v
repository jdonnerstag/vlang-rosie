module rosie

struct Stats {
pub mut:
  	total_time int	// ?? milli- or nano-seconds
  	match_time int	// ?? milli- or nano-seconds
  	instr_count int	// number of vm instructions executed
  	backtrack int  	// max len of backtrack stack used by vm
  	caplist int    	// max len of capture list used by vm 
  	capdepth int   	// max len of capture stack used by walk_captures
}

fn new_stats() Stats {
	return Stats{
	}
}