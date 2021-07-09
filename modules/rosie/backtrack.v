module rosie

// You might think that the VM's runtime which executes the instructions, lends itself
// towards a recursive implementation, but "commit", "fail-twice", "choice" make it
// less it elegant. In my experiments I ended up with 4 return values.

struct BTEntry {
pub mut:
	capidx int	// The index of the capture
	pc int		// program counter: Where to continue upon return 
	pos int		// input position: Where to continue upon return
}