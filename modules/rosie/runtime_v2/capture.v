module runtime_v2


// Capture Often a pattern is made up of simpler pattern. The runtime captures them
// while parsing the input. It basically is the output of a matching process.
// Capture represents a single entry in a tree-like structure of Captures.
struct Capture {
pub:
	parent int			// The index of the parent capture in the list that mmatch is maintaining
	idx int				// Capture name (index)
	level int			// Captures are nested

pub mut:
	start_pos int		// input start position
	end_pos int			// input end position
	matched bool		// whether the input matched the RPL or not
	timer u64
}

[inline]
pub fn (c Capture) text(input string) string { return input[c.start_pos .. c.end_pos] }
