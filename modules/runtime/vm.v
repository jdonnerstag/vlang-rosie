import runtime

//  -*- Mode: C; -*-                                                         
//                                                                           
//  vm.h                                                                     
//                                                                           
//  © Copyright Jamie A. Jennings 2018.                                      
//  Portions Copyright 2007, Lua.org & PUC-Rio (via lpeg)                    
//  LICENSE: MIT License (https://opensource.org/licenses/mit-license.html)  
//  AUTHOR: Jamie A. Jennings                                                

struct Stats {
  	total_time int
  	match_time int
  	insts int	   /* number of vm instructions executed */
  	backtrack int  /* max len of backtrack stack used by vm */
  	caplist int    /* max len of capture list used by vm */
  	capdepth int   /* max len of capture stack used by walk_captures */
}

struct Match {
  	matched i16	  /* boolean; if 0, then ignore data field */
  	abend i16	  /* boolean; meaningful only if matched==1 */
  	leftover u32  /* leftover characters, in bytes */
  	data Buffer
}

/* Kinds of captures 
 *
 * Stored in 'offset', which is 32 bits (way more than we ever need).
 * We will use only the low 8 bits, assume a max of 256 capture types,
 * and reserve bit 8 to indicate a closing capture.
 */
// TODO make names more readable
enum CapKind { 
  	Crosiecap
	Crosieconst 
	Cbackref
  	Cclose = 0x80		/* high bit set */
  	Cfinal
	Ccloseconst
}

const (
    open_capture_names = ["RosieCap", "RosieConst", "Backref"]
    close_capture_names = ["Close", "Final", "CloseConst"]
)

fn capture_name(c int) string {
    if (c & 0x80) != 0 {
        return close_capture_names[c & 0x0F]
    } else {
        return open_capture_names[c & 0x0F]
    }
}

/* Capture 'kind' is 8 bits (unsigned), and 'idx' 24 bits (unsigned).  See rplx.h. */
fn capidx(instr Instruction) int { return instr.qcode() }
fn setcapidx(mut instr Instruction, newidx int) { instr.val = newidx & 0x00ff_ffff } // TODO add boundary test
fn capkind(instr Instruction) int { return instr.aux() }
fn setcapkind(mut instr Instruction, int kind) { instr.val = newidx & 0xff } // TODO add boundary test

struct Capture {
  	s string	/* subject position */
  	c CodeAux	/* .c.code is 'kind' and .c.aux is ktable index */
}

struct CapState {
  	cap Capture			/* current capture */
  	ocap Capture		/* (original) capture list */
  	s string			/* original string */
  	kt Ktable			/* ktable */
} 

fn testchar(st string, c byte) bool {
	mask := 1 << (c & 7)
	return int(st[c >> 3]) & mask
}

fn isopencap(inst Instruction) bool {
	return (inst.qcode() & 0x80) == 0  // test high bit
}

fn isfinalcap(inst Instruction) bool {
	return capkind(inst) == Cfinal
}

fn iscloseapp(inst Instruction) bool {
	return capkind(inst) == Cclose
}

interface Encoder {  
  	open fn (cs CapState, buf Buffer, int count) int
  	close fn (cs CapState, buf Buffer, int count, start string)
}

const (
	giveup = Instruction{ val: IGiveup }
)

struct BTEntry {
  	s string	      /* saved position (or NULL for calls) */
  	p Instruction     /* next instruction */
  	caplevel int
}

/*
 * Size of an instruction
 */
fn sizei(pc Instruction) int {
  	match opcode(pc) {
  		IPartialCommit, ITestAny, IJmp, ICall, IOpenCall, IChoice, ICommit, IBackCommit, IOpenCapture, ITestChar {
	    	return 2
		}
  		ISet, ISpan {
    		return CHARSETINSTSIZE
		}
  		ITestSet {
    		return 1 + CHARSETINSTSIZE
		} 
		else {
			return 1
		}
  	}
}

fn btentry_stack_print(stack []BTEntry, o string, op Instruction) {
	for i = stack.len - 1; i >= 0; i-- {
	   	pos := if top.s == NULL { -1 } else { top.s - o }
	   	pc := if top.p == giveup { -1 } else { top.p - op }
	   	name := OPCODE_NAME(opcode(top.p))
	   	caplevel := top.caplevel

    	eprintln("$i: pos=$pos, pc $pc: $name, caplevel=$caplevel")
	}
}

fn print_caplist(capture Capture, captop int, kt Ktable) {
  	for i in 0 .. captop {
    	if isopencap(capture[i]) {
      		elem := ktable_element(kt, capidx(&capture[i]))
      		print("($i $elem ")
    	} else {
      		if isclosecap(capture[i]) {
				print("$i) ")
      		} else {
				print("** $i ** ")
      		}
    	}
  	}      
  	println("")
}

fn find_prior_capture(capture Capture, captop int, target_idx int, mut s &string, mut e &string, kt Ktable) int {
	if captop == 0 { return 0 }

	if false { // #if BACKREF_DEBUG
  		print_caplist(capture, captop, kt)
		name := ktable_element(kt, target_idx)
  		println("Target is [$target_idx]$name, captop = $captop")
	}

  	/* Skip backwards past any immediate OPENs. */
  	mut i := captop
  	for i = captop - 1; i > 0; i-- {
    	if !isopencap(capture[i]) { break }
  	}

	cap_end := i
	if false {
  		println("declaring this to be the end of the cap list: cap_end = $cap_end")
	}

  	/* Scan backwards for the first OPEN without a CLOSE. */
  	mut outer_cap := 0
  	mut outer_capidx := 0
  	mut balance := 0
  	/* Recall that capture[0] is always an OPEN for the outermost
     capture, which cannot have a matching CLOSE. */
  	for ; i > 0; i-- {
		if false { // #if BACKREF_DEBUG
    		println("looking for first unclosed open, i = $i")
		}

    	if isopencap(capture[i]) {
      		if balance == 0 { break }
      		balance += 1
    	} else {
      		if isclosecap(capture[i]) {
				balance -= 1
      		} 
    	}
  	}
  
  	outer_cap = i
  	outer_capidx = capidx(capture[i])
	if false { // #if BACKREF_DEBUG
  		name := ktable_element(kt, outer_capidx)
  		println("Found FIRST unclosed open at $outer_cap: [$outer_capidx]$name")
	}

  	/* Now search backward from the end for the target, skipping any
     other instances of outer_capidx */

  	for i = cap_end; i >= outer_cap; i-- {
		if false { // #if BACKREF_DEBUG
    		println("looking for target at i=$i")
		}
    	if isopencap(capture[i]) && capidx(capture[i]) == target_idx {
			if false { // #if BACKREF_DEBUG
         		name := ktable_element(kt, outer_capidx)
      			println("found candidate target; now determining if it is inside [$outer_cap]$name")
			}
      		balance = 0
      		mut j := 0
      		for j = i - 1; j >= outer_cap; j-- {
				if isopencap(capture[j]) {
					if false { // #if BACKREF_DEBUG
	  					printf("looking at open capture j = $j")
					}
	  				if balance >= 0 && capidx(capture[j]) == outer_capidx { break }
	  				balance += 1
				} else {
	  				if isclosecap(capture[j]) {
	    				balance -= 1
	  				}
				}
      		}
      		if j == outer_cap {
				if false { // #if BACKREF_DEBUG
					println("No other instances of outer_cap to skip over")
				}
				break /* Nothing to skip over */
      		}
    	}
  	}
  	if i == (outer_cap - 1) {
		if false { // #if BACKREF_DEBUG
    		println("did not find target; continuing the backwards search")
		}
    	for i = outer_cap; i >= 0; i-- {
      		if isopencap(capture[i]) && capidx(capture[i]) == target_idx { break }
	    }
    	if i < 0 { return 0 }
    	if !(isopencap(capture[i]) && capidx(capture[i]) == target_idx) {
      		return 0
    	}
  	}

  	/* This the open capture we are looking for */
	/*   assert (isopencap(&capture[i]) && capidx(&capture[i]) == outer_capidx); */
	if false { // #if BACKREF_DEBUG
    	idx := capidx(capture[i])
		name := ktable_element(kt, idx)
  		println("FOUND open capture at i = $i, [$idx]$name")
	}
  	s = capture[i].s   /* start position */
  	/* Now look for the matching close */
  	i ++
  	mut j := 0
  	for i <= captop {
		if false { // #if BACKREF_DEBUG
    		println("looking at i = $i (captop = $captop)")
		}

    	if isclosecap(capture[i]) {
      		if j == 0 {
				/* This must be the matching close capture */
				if false { // #if BACKREF_DEBUG
					println("i = $i: found close capture")
				}

				e = capture[i].s  /* end position */
				return 1	       /* success */
      		} else {
				j --
				assert j >= 0
      		}
    	} else {
      		assert isopencap(capture[i])
      		j ++
    	}
    	i ++
  	} /* while looking for matching close*/
  	/* Did not find the matching close */
	if false { // #if BACKREF_DEBUG
  		println("did not find matching close!")
	}
	return 0
}

fn print_vm_state() {
	diff := p - op
	name := OPCODE_NAME(p.i.code)
	eprintln("Next instruction: $diff $name")

	n1 := stack.next - stack.base
	limit := STACK_CAPACITY(stack)
	init := if stack.base == &stack.init[0] { "static" } else { "dynamic" }

	eprintln("Stack: next=$n1, limit=$limit, base==init: $init")
}

fn incr_state(action bool, var int) int {
	return if action { var + 1 } else { var }
}

fn update_stat(action bool, mut var &int, value int) {
	if action { var = value }
}

fn update_capstats(inst Instruction) {
	idx := if opcode(inst) == IOpenCapture { addr(inst) } else { Cclose }
	capstats[idx] ++
}

fn push_caplist(captop int) int {
	captop ++
	/* We don't need manual array size adjustments
  	if captop >= capsize {					
    	capture = doublecap(capture, initial_capture, captop)	
    	if !capture {						
      		return MATCH_ERR_CAP
    	}
    	capturebase = capture
    	capsize = 2 * captop
  	}
	*/
	return captop
}

fn jumpby(pc &Instruction, delta int) &Instruction {
	return pc + delta
}

fn vm (mut r &string, o string, s string, e string, op Instruction, mut capturebase &Capture, 
	mut stats &Stats, capstats []int, kt Ktable) int {

	mut stack := []BTEntry{}
  	initial_capture := capturebase
  	mut capture := capturebase
  	capsize := 100 	// INIT_CAPLISTSIZE
  	captop := 0  	/* point to first empty slot in captures */

  	pc = op  /* current instruction */
  	stack << BTEntry{ s: s, p: giveup, caplevel: 0 }
  	for {
    	print_vm_state()
    	incr_stat(stats, stats.insts)
    	match opcode(pc) {
			/* Mark S. reports that 98% of executed instructions are
			* ITestSet, IAny, IPartialCommit (in that order).  So we put
			* them first here, in case it speeds things up.  But with
			* branch prediction, it probably makes no difference.
			*/
    		ITestSet {
      			assert sizei(pc) == (1 + CHARSETINSTSIZE)
      			assert addr(pc) != 0
      			if s < e && testchar((pc + 2).buff, int(s[0])) {
					jumpby(1 + CHARSETINSTSIZE) /* sizei */
				} else {
					jumpby(addr(pc))
				}
    		}
			IAny {
      			assert sizei(pc) == 1
      			if s < e { 
					jumpby(1)
					s ++
				} else 
					goto fail
				}
    		}
    		IPartialCommit {
      			assert sizei(pc) == 2
		      	assert addr(pc)
      			assert stack.next > stack.base && stack.last().s != NULL
      			stack.last().s = s
      			stack.last().caplevel = captop
      			jumpby(addr(pc))
    		}
    		IEnd {
      			assert sizei(pc) == 1
      			assert stack.next == (stack.base + 1)
				/* This Cclose capture is a sentinel to mark the end of the
				* linked caplist.  If it is the only capture on the list,
				* then walk_captures will see it and not go any further.
				*/
      			setcapkind(capture[captop], Cclose)
      			capture[captop].s = NULL
      			update_state(stats, stats.backtrack, stack.maxtop)
      			r = s
      			return MATCH_OK
    		}
    		IGiveup {
      			assert sizei(pc) == 1
      			assert stack.next == stack.base
      			update_stat(stats, stats.backtrack, stack.maxtop)
      			r = NULL
      			return MATCH_OK
    		}
    		IRet {
      			assert sizei(pc) == 1
      			assert stack.next > stack.base
      			assert stack.last().s == NULL
      			pc = stack.last().p
      			stack.pop()
    		}
    		ITestAny {
      			assert sizei(pc) == 2
      			assert addr(pc)
      			if s < e { jumpby(2) } else { jumpby(addr(pc)) }
    		}
    		IChar {
      			assert sizei(pc) == 1
      			if s < e && s[0] == ichar(pc) { 
					jumpby(1)
					s++ 
				} else {
      				goto fail
				}
    		}
    		ITestChar {
      			assert sizei(pc) == 2
      			assert addr(pc)
      			if s < e && s[0] == ichar(pc) { jumpby(2) } else { jumpby(addr(pc)) }
    		}
    		ISet {
      			assert sizei(pc) == CHARSETINSTSIZE
      			if s < e && testchar((pc + 1).buff, int(s[0])) {
					jumpby(CHARSETINSTSIZE) /* sizei */
	  				s ++
				} else { 
					goto fail 
				}
    		}
    		IBehind {
      			assert sizei(pc) == 1
      			n := index(pc)
      			if n > s - o { goto fail }
      			s -= n
				jumpby(1)
    		}
    		ISpan {
      			assert sizei(pc) == CHARSETINSTSIZE
      			for ; s < e; s++ {
					if !testchar((pc + 1).buff, int(s[0])) { break }
      			}
      			jumpby(CHARSETINSTSIZE)	/* sizei */
    		}
    		IJmp {
      			assert sizei(pc) == 2
      			assert addr(pc)
      			jumpby(addr(pc))
    		}
    		IChoice {
      			assert sizei(pc) == 2
      			assert addr(pc)
      			stack << BTEntry{ s: s, p: pc + addr(pc), captop: captop }
      			jumpby(2)
    		}
    		ICall {
      			assert sizei(pc) == 2
      			assert addr(pc)
      			stack << BTEntry{ s: NULL, p: pc + 2, captop: 0 }
      			jumpby(addr(pc))
    		}
    		ICommit {
      			assert sizei(pc) == 2
      			assert addr(pc)
      			assert stack.next > stack.base && stack.last().s != NULL
      			stack.pop()
      			jumpby(addr(pc))
    		}
    		IBackCommit {
      			assert sizei(pc) == 2
      			assert addr(pc) != 0
      			assert stack.next > stack.base && stack.last().s != NULL
      			s = stack.last().s
      			captop = stack.last().caplevel
      			stack.pop()
      			jumpby(addr(pc))
    		}
    		IFailTwice {
      			assert stack.next > stack.base
      			stack.pop()
			}
    		IFail {
      			assert stack.next > stack.base
      			stack.pop()
      			assert sizei(pc) == 1
    			fail: { /* pattern failed: try to backtrack */
        		for {  /* remove pending calls */
          			assert stack.next > stack.base
          			s = stack.last().s
	  				stack.pop()
					if s != NULL { break }
        		}
        		captop = stack[stack.len - 2].caplevel
        		pc = stack[stack.len - 2].p
      		}
    		IBackref {
      			assert sizei(pc) == 1
      			/* Now find the prior capture that we want to reference */
      			startptr = ""
      			endptr = ""
      			target := index(pc)
      			//printf("Entering IBackref, target = %d\n", target)
      			have_prior := find_prior_capture(capture, captop, target, &startptr, &endptr, kt)
      			//printf("%s:%d: have_prior is %s\n", __FILE__, __LINE__, have_prior ? "true" : "false")
      			if have_prior {
					assert startptr && endptr
					assert endptr >= startptr
					prior_len := endptr - startptr
					//printf("%s:%d: prior data is at %zu (0-based) is '%.*s'\n", __FILE__, __LINE__,
					//     (startptr - o),
					//     (int) prior_len, startptr)
					/* And check to see if the input at the current position */
					/* matches that prior captured text. */
					//printf("%s:%d: looking at %zu (0-based) '%.*s'\n", __FILE__, __LINE__,
					//       (e - o),
					//     (int) (e - s), s)
					if (e - s) >= prior_len && memcmp(s, startptr, prior_len) == 0 {
	  					s += prior_len
	  					jumpby(1)
	  					//printf("%s:%d: input matched prior!\n", __FILE__, __LINE__)
					} /* if input matches prior */
					//printf("%s:%d: input did not match prior\n", __FILE__, __LINE__)
      			}	/* if have a prior match at all */
      			//printf("%s:%d: input did not match or found no prior\n", __FILE__, __LINE__)
      			/* Else no match. */
      			goto fail
    		}
    		ICloseConstCapture {
      			assert sizei(pc) == 1
      			assert index(pc) != 0
      			assert captop > 0
      			capture[captop].s = s
      			setcapidx(capture[captop], index(pc)) /* second ktable index */
      			setcapkind(capture[captop], Ccloseconst)
      			goto pushcapture
    		}
    		ICloseCapture {
      			assert sizei(pc) == 1
      			assert captop > 0
				/* Roberto's lpeg checks to see if the item on the stack can
				be converted to a full capture.  We skip that check,
				because we have removed full captures.  This makes the
				capture list 10-15% longer, but saves almost 2% in time.
				*/
      			capture[captop].s = s
      			setcapkind(capture[captop], Cclose)
      			pushcapture:		/* push, jump by 1 */
      				update_capstats(pc)
      				push_caplist()
      				update_stat(stats, stats.caplist, captop)
      				jumpby(1)
    		}
    		IOpenCapture {
      			assert sizei(pc) == 2
      			capture[captop].s = s
      			setcapidx(capture[captop], index(pc)) /* ktable index */
      			setcapkind(capture[captop], addr(pc)) /* kind of capture */
      			update_capstats(pc)
      			push_caplist()
      			update_stat(stats, stats.caplist, captop)
      			jumpby(2)
    		}
    		IHalt {				    /* rosie */
      			assert sizei(pc) == 1
				/* We could unwind the stack, committing everything so that we
				can return everything captured so far.  Instead, we simulate
				the effect of this in caploop() in lpcap.c.  (And that loop
				is something we should be able to eliminate!)
				*/
      			setcapkind(capture[captop], Cfinal)
      			capture[captop].s = s
      			r = s
      			update_state(stats, stats.backtrack, stack.maxtop)
      			return MATCH_OK
    		}
			else {
      			if false { // (VMDEBUG) {
					pos := int(pc - op)
					eprintln("Illegal opcode at $pos: ${opcode(pc)}")
					printcode(op)		/* print until IEnd */
      			}
      			assert false
      			return MATCH_ERR_BADINST
    		} 
		}
  	}
}

/*
 * Get the initial position for the match, interpreting negative
 * values from the end of the input string, using Lua convention,
 * including 1-based indexing.
 */
fn initposition(pos int, len int) int {
  	if pos > 0 {		/* positive index? */
    	if pos <= len {	/* inside the string? */
      		return pos - 1	/* correct to 0-based indexing */
		} else {
			return len		/* crop at the end */
  		}
  	} else {			     /* negative index */
    	if -pos <= len {	     /* inside the string? */
      		return len - -pos /* return position from the end */
	  	} else {
		  	return 0		     /* crop at the beginning */
	  	}
  	}
}

/* -------------------------------------------------------------------------- */

struct Cap {
  	start string	// TODO probably we need an index
  	count int
}

/* caploop() processes the sequence of captures created by the vm.
   This sequence encodes a nested, balanced list of Opens and Closes.

   caploop() would naturally be written recursively, but a few years
   ago, I rewrote it in the iterative form it has now, where it
   maintains its own stack.

   The stack is used to match up a Close capture (when we encounter it
   as we march along the capture sequence) with its corresponding Open
   (which we have pushed on our stack).

   The 'count' parameter contains the number of captures inside the
   Open at the top of the stack.  When it is not zero, the JSON
   encoder starts by emitting a comma "," because it is encoding a
   capture that is within a list of nested captures (but is not the
   first in that list).  Without 'count', a spurious comma would
   invalidate the JSON output.

   Note that the stack grows with the nesting depth of captures.  As
   of this writing (Friday, July 27, 2018), this depth rarely exceeds
   7 in the patterns we are seeing.
 */

fn capstart(cs) string { // TODO return pos`?
	return capkind(cs.cap) == Crosieconst { -1 } else { cs.cap.s }
}

fn caploop(cs CapState, encode Encoder, buf Buffer, max_capdepth int) ?int {
  	mut count := 0
  	mut stack := []Cap{}
  	stack << Cap{ start: capstart(cs), count: 0 }

  	encode.open(cs, buf, 0)?
  	cs.cap ++
  
  	for stack.len > 0 {
    	for isopencap(cs.cap) {
      		stack << Cap{ start: capstart(cs), count: count }
      		encode.Open(cs, buf, count)?
      		count = 0
      		cs.cap ++
    	}
    	count = stack.last().count
    	start = stack.last().start
    	stack.pop()
		/* We cannot assume that every Open will be followed by a Close,
		* due to the (Rosie) introduction of a non-local exit (throw) out
		* of the lpeg vm.  We use a sentinel, a special Close different
		* from the one inserted by IEnd.  Here (below), we will look to
		* see if the Close is that special sentinel.  If so, then for
		* every still-open capture, we will synthesize a Close that was
		* never created because a non-local exit occurred.
		*
		* FUTURE: Maybe skip the creation of the closes?  Leave the
		* sentinel for the code that processes the captures to deal with.
		* I.e. emulate all the missing Closes there.  This is an
		* optimization that will only come into play when Halt is used,
		* though.  So it is NOT a high priority.
		*/
    	if isfinalcap(cs.cap) {
      		synthetic := Capture{ s: cs.cap.s }
      		setcapidx(synthetic, 0)
      		setcapkind(synthetic, Cclose)
      		// synthetic.siz = 1	/* 1 means closed */
      		cs.cap = synthetic
      		for {
				encode.close(cs, buf, count, start)?
				if stack.len == 0 { break }
				stack.pop()
				count = stack.last().count
				start = stack.last().start
      		}
      		max_capdepth = stack.maxtop
      		return MATCH_HALT
    	}
    	assert isopencap(cs.cap) == false
    	encode.close(cs, buf, count, start)?
    	cs.cap ++
    	count ++
  	}
  	max_capdepth = stack.maxtop
  	return MATCH_OK
}

/*
 * Prepare a CapState structure and traverse the entire list of
 * captures in the stack pushing its results. 's' is the subject
 * string. Call the output encoder functions for each capture (open,
 * close, or full).
 */
fn walk_captures(capture Capture, s string, kt Ktable, encode Encoder,
			  /* outputs: */
			  mut buf Buffer, mut abend int, mut stats Stats) int {
  	abend = 0		       /* 0 => normal completion; 1 => halt/throw */
  	if isfinalcap(capture) {
    	abend = 1
    	goto done
  	}
  	if !isclosecap(capture) {  /* Any captures? */
    	cs := CapState{ ocap: cs.cap = capture, s: s, kt: kt }
		/* Rosie ensures that the pattern has an outer capture.  So
		* if we see a full capture, it is because the outermost
		* open/close was converted to a full capture.  And it must be the
		* only capture in the capture list (except for the sentinel
		* Cclose put there by the IEnd instruction.
		*/
    	mut max_capdepth := 0
    	rtn := caploop(&cs, encode, buf, &max_capdepth)
    	update_stat(stats, stats.capdepth, max_capdepth)
    	if rtn == MATCH_HALT {
      		abend = 1
      		goto done
    	} else {
      		if rtn != 0 { return err }
		}
  	}
 	done:
  		return MATCH_OK
}

fn vm_match(chunk Chunk, input Buffer, start int, encode Encoder,
	      /* outputs: */ mut mmatch Match, mut stats Stats) int {

  	initial_capture := []Capture{ cap: 30 }
  	capture_idx := 0

	t0 := clock()
  	s := input.data
  	l := input.n

  	if l > UINT_MAX { return MATCH_ERR_INPUT_LEN }

  	i := initposition(start, l)
  	capstats := []int{ len: 256, init: 0 }

  	// PASSING KTABLE TO VM ONLY FOR DEBUGGING
  	err = vm(r, s, s + i, s + l, chunk.code, capture, stats, capstats, chunk.ktable)

	if false { #if (VMDEBUG) 
  		r = if r != 0 { r - s } else { 0 }
  		println("vm() completed with err code $err, r as position = $r")
  		if stats { println("vm executed ${stats.insts} instructions")
  		println("capstats from vm: Close ${capstats[Cclose]}, Rosiecap ${capstats[Crosiecap]}") 
  		for ii = 0; ii < 256; ii++ {
    		if !(ii in [Cclose, Crosiecap, Crosieconst, Cbackref]) {
      			assert capstats[ii] == 0
			}
		}
	} 

  	tmatch := clock()

  	if err != MATCH_OK { return err }
  	if stats { stats.match_time += tmatch - t0 }
  	if r == NULL {
		/* We leave match.data alone, because it may be reused over
		* successive calls to match().
		*/
    	mmatch.matched = 0			/* no match */
    	mmatch.leftover = l /* leftover value is len */
    	mmatch.abend = 0
    	if stats { stats.total_time += tmatch - t0 } /* match time (vm only) */
    	return MATCH_OK
  	}
  	mmatch.matched = 1		/* match */
  	if !mmatch.data { mmatch.data = buf_new(0) }
  	if !mmatch.data { return MATCH_ERR_OUTPUT_MEM }

  	err = walk_captures(capture, s, chunk.ktable, encode, mmatch.data, abend, stats)
  	if err != MATCH_OK { return err }

  	tfinal := clock()
  	mmatch.leftover = l - (r - s) /* leftover chars, in bytes */
  	mmatch.abend = abend
  	if stats { stats.total_time += tfinal - t0 } /* total time (includes capture processing) */

  	return MATCH_OK
}

fn new_match() Match {
  	return Match{}
}
