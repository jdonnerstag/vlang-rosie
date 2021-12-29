module v1

// BTEntry You might think that the VM's runtime which executes the instructions, lends itself
// towards a recursive implementation, but "choice" and "call" are orthogonal to
// "open-capture" and "commit". That is, the call hierachy and the capture hierachy
// do not align.
struct BTEntry {
pub mut:
	capidx int	// The index of the capture
	pc int		// program counter: Where to continue upon return
	pos int		// input position: Where to continue upon return
}
