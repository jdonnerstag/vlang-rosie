module rosie

/* Kinds of captures 
 *
 * Stored in 'offset', which is 32 bits (way more than we ever need).
 * We will use only the low 8 bits, assume a max of 256 capture types,
 * and reserve bit 8 to indicate a closing capture.
 */
// TODO Not convinced I like that "high bit" tweak
// TODO Any idea what the meaning of each kind is?
enum CapKind { 
  	rosie_cap
	rosie_const 
	backref
	close = 0x80	// high bit set
  	final			// will also have high-bit set
	close_const		// And this one as well.
}

fn (ck CapKind) name() string {
	return match ck {
		.rosie_cap { "Rosie-Cap" }
		.rosie_const { "Rosie-Const" }
		.backref { "Backref" }
		.close { "Close" }
		.final { "Final" }
		.close_const { "Close-Const" }
	}
}

// TODO I hate one-letter var names
struct Capture {
pub mut:
  	s int			// subject position  // TODO position of what?
  	c CapKind
}

type CaptureList = []Capture

struct CapState {
pub mut:
  	idx int				// current capture (index) 
  	caps []Capture		// capture list
  	s string			// original string
  	kt Ktable			// ktable
} 

// TODO probably we need an index. Or a substring view ??
// TODO what is the difference between Capture and Cap ??
struct Cap {
pub mut:
  	start int	
  	count int
}

// -------------

//[inline]
fn (cap CapKind) isopencap() bool { return (int(cap) & 0x80) == 0 }

//[inline]
fn (cap CapKind) isclosecap() bool { return cap.isopencap() == false }

//[inline]
fn (cap CapKind) isfinalcap() bool { return cap == .final }

//[inline]
fn (cap CapKind) iscloseapp() bool { return cap == .close }

// -------------

//[inline]
fn (cap Capture) isopencap() bool { return cap.c.isopencap() }

//[inline]
fn (cap Capture) isclosecap() bool { return cap.c.isclosecap() }

//[inline]
fn (cap Capture) isfinalcap() bool { return cap.c.isfinalcap() }

//[inline]
fn (cap Capture) iscloseapp() bool { return cap.c.iscloseapp() }

// -------------

fn (caplist []Capture) print(kt Ktable) {
  	for i, cap in caplist {
    	if cap.isopencap() {
      		elem := kt.elems[cap.s]	// TODO orig: cap.capidx() 
      		print("($i $elem ")
    	} else {
      		if cap.isclosecap() {
				print("$i) ")
      		} else {
				print("** $i ** ")
      		}
    	}
  	}      
  	println("")
}

// ---------------------------------------------------------------------------

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

fn (cs CapState) capstart() int { 
	cap := cs.caps[cs.idx]
	return if cap.c == CapKind.rosie_const { -1 } else { cap.s }
}

fn (mut cs CapState) caploop(encode Encoder, buf Buffer, mut max_capdepth &int) MatchErrorCodes {
  	mut stack := []Cap{ cap: 10 }
  	stack << Cap{ start: cs.capstart(), count: 0 }

  	encode.open(&cs, &buf, 0)
  	cs.idx ++
  
  	mut count := 0
  	mut start := 0

  	for stack.len > 0 {
    	for cs.caps[cs.idx].isopencap() {
      		stack << Cap{ start: cs.capstart(), count: count }
      		encode.open(&cs, &buf, count)
      		count = 0
      		cs.idx ++
    	}

    	mut last := stack.pop()
    	count = last.count
    	start = last.start

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
    	if cs.caps[cs.idx].isfinalcap() {
      		cs.caps[cs.idx] = Capture{ s: cs.caps[cs.idx].s, c: CapKind.close }
      		for stack.len > 0 {
				encode.close(&cs, &buf, count, start)
				last = stack.pop()
				count = last.count
				start = last.start
      		}
      		max_capdepth = 1 // stack.maxtop
      		return MatchErrorCodes.halt
    	}

    	assert cs.caps[cs.idx].isclosecap() == true
    	encode.close(&cs, &buf, count, start)
    	cs.idx ++
    	count ++
  	}

  	max_capdepth = 1 // stack.maxtop
  	return MatchErrorCodes.ok
}

// Prepare a CapState structure and traverse the entire list of
// captures in the stack pushing its results. 's' is the subject
// string. Call the output encoder functions for each capture (open,
// close, or full).
fn (mut caps []Capture) walk_captures(s string, kt Ktable, encode Encoder,
			  /* outputs: */
			  mut buf &Buffer, mut abend &bool, mut stats &Stats) MatchErrorCodes {

  	abend = 0	// 0 => normal completion; 1 => halt/throw; TODO: replace with enum

  	caps0 := caps[0]
  	if caps0.isfinalcap() {
    	abend = 1
    	return MatchErrorCodes.ok
  	} 
	  
	if caps0.isopencap() {  
    	mut cs := CapState{ caps: caps, idx: 0, s: s, kt: kt }

		/* Rosie ensures that the pattern has an outer capture.  So
		* if we see a full capture, it is because the outermost
		* open/close was converted to a full capture.  And it must be the
		* only capture in the capture list (except for the sentinel
		* Close put there by the IEnd instruction.
		*/
    	mut max_capdepth := 0
    	err := cs.caploop(encode, buf, mut max_capdepth)
    	stats.capdepth = max_capdepth
    	if err == MatchErrorCodes.halt {
      		abend = 1
      		return MatchErrorCodes.ok
    	} else if err != MatchErrorCodes.ok { 
			return err
		}
  	}

	return MatchErrorCodes.ok
}

fn (mut caps []Capture) find_prior_capture(target_idx int, mut s &string, mut e &string, kt Ktable) bool {
	if caps.len == 0 { return false }

	if false { // #if BACKREF_DEBUG
  		caps.print(kt)
		name := kt.elems[target_idx]
  		println("Target is [$target_idx]$name, captop = $caps.len")
	}

  	/* Skip backwards past any immediate OPENs. */
  	mut i := caps.len
  	for i = caps.len - 1; i > 0; i-- {
    	if caps[i].isclosecap() { break }
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

    	if caps[i].isopencap() {
      		if balance == 0 { break }
      		balance += 1
    	} else {
      		if caps[i].isclosecap() {
				balance -= 1
      		} 
    	}
  	}
  
  	outer_cap = i
  	outer_capidx = i // TODO caps[i].capidx()
	if false { // #if BACKREF_DEBUG
  		name := kt.elems[outer_capidx]
  		println("Found FIRST unclosed open at $outer_cap: [$outer_capidx]$name")
	}

  	/* Now search backward from the end for the target, skipping any
     other instances of outer_capidx */

  	for i = cap_end; i >= outer_cap; i-- {
		if false { // #if BACKREF_DEBUG
    		println("looking for target at i=$i")
		}
    	if caps[i].isopencap() && i /* caps[i].capidx() */ == target_idx {
			if false { // #if BACKREF_DEBUG
         		name := kt.elems[outer_capidx]
      			println("found candidate target; now determining if it is inside [$outer_cap]$name")
			}
      		balance = 0
      		mut j := 0
      		for j = i - 1; j >= outer_cap; j-- {
				if caps[j].isopencap() {
					if false { // #if BACKREF_DEBUG
	  					println("looking at open capture j = $j")
					}
	  				if balance >= 0 && j /* caps[j].capidx() */ == outer_capidx { break }
	  				balance += 1
				} else {
	  				if caps[j].isclosecap() {
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
      		if caps[i].isopencap() && i /* caps[i].capidx() */ == target_idx { break }
	    }
    	if i < 0 { return false }
    	if !(caps[i].isopencap() && i /* caps[i].capidx() */ == target_idx) {
      		return false
    	}
  	}

  	/* This the open capture we are looking for */
	/*   assert (isopencap(&capture[i]) && capidx(&capture[i]) == outer_capidx); */
	if false { // #if BACKREF_DEBUG
    	idx := i /* caps[i].capidx() */
		name := kt.elems[idx]
  		println("FOUND open capture at i = $i, [$idx]$name")
	}
  	/* s = caps[i].s */  /* start position */
  	/* Now look for the matching close */
  	i ++
  	mut j := 0
  	for i <= caps.len {
		if false { // #if BACKREF_DEBUG
    		println("looking at i = $i (captop = $caps.len)")
		}

    	if caps[i].isclosecap() {
      		if j == 0 {
				/* This must be the matching close capture */
				if false { // #if BACKREF_DEBUG
					println("i = $i: found close capture")
				}

				/* e = caps[i].s */ /* end position */
				return true	       /* success */
      		} else {
				j --
				assert j >= 0
      		}
    	} else {
      		assert caps[i].isopencap()
      		j ++
    	}
    	i ++
  	} /* while looking for matching close*/
  	/* Did not find the matching close */
	if false { // #if BACKREF_DEBUG
  		println("did not find matching close!")
	}
	return false
}
