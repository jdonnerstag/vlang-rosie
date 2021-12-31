module v2

struct BTEntry {
pub mut:
	capidx int		// Remember the capture to return to, when poping the choice
	pos int			// Remember the input position to return to, if a pattern does not match
	pc int			// program counter: A jump to address when poping the choice
}
