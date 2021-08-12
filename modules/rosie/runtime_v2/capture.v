module runtime_v2

// Capture Often a pattern is made up of simpler pattern. The runtime captures them
// while parsing the input. It basically is the output of a matching process.
// Capture represents a single entry in a tree-like structure of Captures.
struct Capture {
pub:
	parent int			// The index of the parent capture in the list that mmatch is maintaining
	name string			// Capture name
	level int			// Captures are nested

pub mut:
  	start_pos int		// input start position
  	end_pos int			// input end position
	matched bool		// whether the input matched the RPL or not
}

// print A nice little helper to print the capture output in a tree-like way
// which helps to understand the structure.
fn (caplist []Capture) print(match_only bool) {
	eprintln("--- Capture Tree ---")

	mut level := -1
  	for i, cap in caplist {
		if match_only {
			if level >= 0 && cap.level > level {
				continue
			}

			if cap.matched == false {
				level = cap.level
				continue
			}
		}

		level = -1
		eprint("${i:3d} ")
		eprint("-".repeat(1 + cap.level * 2))
		eprintln(" ${cap.name}, matched=$cap.matched, parent=$cap.parent, $cap.start_pos .. $cap.end_pos")
  	}
}

// find Find a specific Capture by its pattern name
pub fn (caplist []Capture) find(name string, input string, matched bool) ?string {
	for cap in caplist {
		if (matched || cap.matched) && cap.name == name {
			return input[cap.start_pos .. cap.end_pos]
		}
	}
	return none
}

// find Find a specific Capture by its pattern name
pub fn (caplist []Capture) find_cap(name string, matched bool) ?Capture {
	for cap in caplist {
		if (matched || cap.matched) && cap.name == name {
			return cap
		}
	}
	return none
}
