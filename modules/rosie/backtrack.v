module rosie

// Backtracking, is what regular expressions do naturally during the course of 
// matching when a match fails. For example, if I'm matching the expression
//   .+b   against the string   "aaaaaabcd"
// then it will first match "aaaaaabc" on the ".+" and then compare "b" against 
// the remaining "d". This fails, so it backtracks a bit and matches "aaaaaab" 
// for the .+ and then compares the final "b" against the "c". This fails too, 
// so it backtracks again and tries "aaaaaa" for the .+ and the "b" against the 
// "b" and succeeds.

struct BTEntry {
pub mut:
	// TODO I hate one-letter var names => rename
  	s int	    	// TODO saved position in input data ?? (or -1 for calls)
  	pc int			// program counter
   	//caplevel int	// ??
}

fn new_btstack() []BTEntry{
	return []BTEntry{ cap: 10 }
}

// TODO What is the meaning of the "o" and "op" variables?
fn (stack []BTEntry) print(byte_code []Instruction) {
    println("Backtrack Stack: len=$stack.len")

	// TODO Does V support ranges that are counting down? E.g. for i in stack.len .. 0 
	// TODO Or some reverse_iterator, e.g. for x in myar.reverse_iter() ...
	for i := stack.len - 1; i >= 0; i-- {
		elem := stack[i]
	   	pos := elem.s
	   	pc := elem.pc
	   	name := byte_code[pc].opcode().name()
	   	//caplevel := elem.caplevel

		// TODO What is the difference between pos and pc?
    	println("$i: pos=$pos, pc=$pc, '$name'")
	}
}

// pattern failed: try to backtrack 
fn (mut stack []BTEntry) on_fail() ?int {
	// remove pending calls
	for stack.len > 0 {  
		last := stack.pop()
		// TODO What does it mean if .s == -1 ??? When does it happen?
		if last.s != -1 { return 1 /* last.p */ }	// TODO
	}
	return none
}
