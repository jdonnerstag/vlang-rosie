module rosie

//  -*- Mode: C; -*-                                                         
//                                                                           
//  vm.h                                                                     
//                                                                           
//  © Copyright Jamie A. Jennings 2018.                                      
//  Portions Copyright 2007, Lua.org & PUC-Rio (via lpeg)                    
//  LICENSE: MIT License (https://opensource.org/licenses/mit-license.html)  
//  AUTHOR: Jamie A. Jennings                                                

enum MatchErrorCodes {
	ok
	halt
	err_badinst
}

const (
	giveup = new_opcode_instruction(Opcode.giveup)
)

fn (mut mmatch Match) print_vm_state(pc int) {
	name := mmatch.instruction(pc).opcode().name()
	eprintln("Next instruction: pc=$pc $name")
}
/*
fn (mut mmatch Match) update_capstats(instr Instruction) {
	mmatch.capstats[int(instr.opcode())] ++
}
*/
fn (mut mmatch Match) vm(start_pc int) ?MatchErrorCodes {
	mut btstack := new_btstack()
  	captures := mmatch.captures
  	btstack << BTEntry{ s: mmatch.data.pos, pc: -1, caplevel: captures.len }

	mut captop := btstack.last().caplevel
  	mut pc := start_pc 	// current instruction 
  	for !mmatch.eof(pc) {
    	if mmatch.debug > 9 { mmatch.print_vm_state(pc) }
    	mmatch.stats.instr_count ++

		instr := mmatch.instruction(pc)
		opcode := instr.opcode()
    	match opcode {
			/* Mark S. reports that 98% of executed instructions are
			* ITestSet, IAny, IPartialCommit (in that order).  So we put
			* them first here, in case it speeds things up.  But with
			* branch prediction, it probably makes no difference.
			*/
    		.test_set {
      			if mmatch.leftover() > 0 && testchar(mmatch.data.peek_byte()?, mmatch.rplx.code, pc + 1) {
					mmatch.data.pos ++
				}
    		}
			.any {
      			if mmatch.leftover() > 0 { 
					mmatch.data.pos ++
				} else { 
	    			captop, pc = btstack.on_fail() or { break } // pattern failed: try to backtrack
				}
    		}
    		.partial_commit {	
				mut last := btstack.last()
      			last.s = pc		// TODO Is this updating the entry on the stack? I don't think so.
      			last.caplevel = captop
      			pc = mmatch.instruction(pc + 1).val
    		}
    		.end {
				// This Close capture is a sentinel to mark the end of the
				// linked caplist. If it is the only capture on the list,
				// then walk_captures will see it and not go any further.
      			mut last := captures.last()
				//last.setcapkind(CapKind.close)		// TODO I don't think this updates the value on the stack ?!?!
      			last.s = -1
      			mmatch.stats.backtrack = 1 // stack.maxtop
      			return MatchErrorCodes.ok
    		}
    		.giveup {
      			mmatch.stats.backtrack = 1 // stack.maxtop
      			return MatchErrorCodes.ok
    		}
    		.ret {
      			pc = btstack.pop().pc
    		}
    		.test_any {		// How exactly does this work?
      			if mmatch.leftover() > 0 { 
					mmatch.data.pos += 1
				} else { 
	      			pc = mmatch.instruction(pc + 1).val
				}
    		}
    		.char, .test_char {
      			if mmatch.leftover() > 0 && mmatch.data.peek_byte()? == mmatch.instruction(pc + 1).ichar() { 
					mmatch.data.pos ++
				} else {
	    			captop, pc = btstack.on_fail() or { break } // pattern failed: try to backtrack
				}
    		}
    		.set {
      			if mmatch.leftover() > 0 && testchar(mmatch.data.peek_byte()?, mmatch.rplx.code, pc + 1) {
					mmatch.data.pos ++
				} else { 
	    			captop, pc = btstack.on_fail() or { break } /* pattern failed: try to backtrack */
				}
    		}
    		.behind { // TODO don#t understand what it is doing
			/*
      			n := index(pc)
      			if n > s - o { 
	    			captop, pc = btstack.on_fail() or { break } /* pattern failed: try to backtrack */
				}
				mmatch.data.pos -= n
			*/
    		}
    		.span {
      			for mmatch.leftover() > 0 {
	      			if !testchar(mmatch.data.peek_byte()?, mmatch.rplx.code, pc + 1) { break }
					mmatch.data.pos ++
      			}
    		}
    		.jmp {
      			pc = mmatch.addr(pc)
    		}
    		.choice {
      			btstack << BTEntry{ s: mmatch.data.pos, pc: pc /* , captop: captop */ }
    		}
    		.call {
      			btstack << BTEntry{ s: -1, pc: pc + 2 /* , captop: 0 */ }
      			pc = mmatch.addr(pc)
    		}
    		.commit {
      			btstack.pop()
      			pc = mmatch.addr(pc)
    		}
    		.back_commit {
				last := btstack.last()
      			//s := last.s
      			captop = last.caplevel
      			btstack.pop()
      			pc = mmatch.addr(pc)
    		}
    		.fail_twice {
      			btstack.pop()
			}
    		.fail {
      			btstack.pop()
    			captop, pc = btstack.on_fail() or { break } // pattern failed: try to backtrack
      		}
    		.backref {
      			// Now find the prior capture that we want to reference
      			mut startptr := ""
      			mut endptr := ""
      			mut target := pc
      			have_prior := mmatch.captures.find_prior_capture(captop, target, mut startptr, mut endptr, mmatch.rplx.ktable)
      			//printf("%s:%d: have_prior is %s\n", __FILE__, __LINE__, have_prior ? "true" : "false")
      			if have_prior {
					/*
					prior_len := endptr - startptr
					if (e - s) >= prior_len && memcmp(s, startptr, prior_len) == 0 {
	  					s += prior_len
	  					pc += 1
					}
					*/ 
      			}
      			// Else no match.
    			captop, pc = btstack.on_fail() or { break } /* pattern failed: try to backtrack */
    		}
    		.close_const_capture {
      			mut cap := captures[captop]		// TODO if the idea is to modify the top entry, then it'll fail
      			cap.s = pc
      			//setcapidx(cap, pc) // second ktable index 
      			//setcapkind(cap, CapKind.close_const)

				//update_capstats(pc)
				mmatch.stats.caplist = captop
    		}
    		.close_capture {
				// Roberto's lpeg checks to see if the item on the stack can
				// be converted to a full capture.  We skip that check,
				// because we have removed full captures.  This makes the
				// capture list 10-15% longer, but saves almost 2% in time.
      			mut cap := mmatch.captures[captop]
				cap.s = pc
      			//setcapkind(cap, CapKind.close)

				//update_capstats(pc)
				mmatch.stats.caplist = captop
    		}
    		.open_capture {
      			mut cap := mmatch.captures[captop]
      			cap.s = pc
      			//setcapidx(cap, pc) 	// ktable index 
      			//setcapkind(cap, addr(pc)) 	// kind of capture
      			//update_capstats(pc)
      			mmatch.stats.caplist = captop
    		}
    		.halt {	// rosie
				// We could unwind the stack, committing everything so that we
				// can return everything captured so far.  Instead, we simulate
				// the effect of this in caploop() in lpcap.c.  (And that loop
				// is something we should be able to eliminate!)
      			mut cap := mmatch.captures[captop]
      			//setcapkind(cap, CapKind.final)
      			cap.s = pc
      			mmatch.stats.backtrack = 1 // stack.maxtop
      			return MatchErrorCodes.ok
    		}
			else {
      			if mmatch.debug > 2 { // (VMDEBUG) {
					eprintln("Illegal opcode at $pc: ${opcode}")
					//op.printcode()		// print until IEnd
      			}
      			assert false
      			return MatchErrorCodes.err_badinst
    		} 
		}
		pc += instr.sizei()
  	}
	return MatchErrorCodes.ok
 }

fn (mut mmatch Match) vm_match(input string, encode Encoder) ?MatchErrorCodes {
	// Put the input data into a buffer, so that we can track 
	// the current position (cursor)
	mmatch.data = Buffer{ data: input.bytes() }

	// capstats is a (sparse) look-up table, indexed by CapKind
  	capstats := []int{ len: 256, init: 0 }

  	mut err := mmatch.vm(0)?
  	//mmatch.t1 = clock()

	if mmatch.debug > 0 {
  		println("vm() completed with err code $err")
  		if mmatch.debug > 0 { 
		  	println("vm executed ${mmatch.stats.instr_count} instructions") 
		}

  		println("capstats from vm: Close ${capstats[CapKind.close]}, Rosiecap ${capstats[CapKind.rosie_cap]}") 

  		for ii in 0 .. capstats.len {
			x := capstats[ii]
    		if !(x in [int(CapKind.close), int(CapKind.rosie_cap), int(CapKind.rosie_const), int(CapKind.backref)]) {
      			assert x == 0
			}
		}
	} 

  	if err != MatchErrorCodes.ok { 
		return err 
	}

  	if false /* r == NULL */ {
    	mmatch.matched = false		// no match 
    	mmatch.abend = false
    	//mmatch.stats.total_time += mmatch.t1 - mmatch.t0  // match time (vm only) 
    	return MatchErrorCodes.ok
  	}

  	mmatch.matched = true		// match

  	err = mmatch.captures.walk_captures(input, mmatch.rplx.ktable, encode, mut mmatch.data, mut mmatch.abend, mut mmatch.stats)
  	if err != MatchErrorCodes.ok { 
		return err 
	}

  	mmatch.stats.total_time += 0 // tfinal - t0  // total time (includes capture processing // TODO: review 

  	return MatchErrorCodes.ok
}
