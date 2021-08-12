module runtime_v2

struct BTEntry {
pub mut:
	capidx int	// The index of the capture upon entering the frame
	pc int		// program counter: Where to continue upon return
	pos int		// input position upon entering the frame
}
