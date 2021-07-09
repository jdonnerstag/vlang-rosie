module rosie

struct Capture {
pub:
	parent int			// TODO remove parent again
	name string			// Capture name 
	level int			// Captures are nested

pub mut:
  	start_pos int		// input start position
  	end_pos int			// input end position
	matched bool		// whether the input matched the RPL or not
} 

fn (caplist []Capture) print() {
  	for i, cap in caplist {
		println("$i ${cap.name}, level=$cap.level, matched=$cap.matched, $cap.start_pos .. $cap.end_pos")
  	}      
}

pub fn (caplist []Capture) find(name string, input string) ?string {
	for cap in caplist {
		if cap.matched && cap.name == name {
			return input[cap.start_pos .. cap.end_pos]
		}
	}
	return none
}
