module rosie

//  -*- Mode: C; -*-                                                         
//                                                                           
//  vm.h                                                                     
//                                                                           
//  © Copyright Jamie A. Jennings 2018.                                      
//  Portions Copyright 2007, Lua.org & PUC-Rio (via lpeg)                    
//  LICENSE: MIT License (https://opensource.org/licenses/mit-license.html)  
//  AUTHOR: Jamie A. Jennings                                                

pub enum MatchErrorCodes {
	ok
	no_match
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
	if mmatch.debug > 0 { eprintln("vm: enter: '$mmatch.data.data.bytestr()'") }
	defer {	if mmatch.debug > 0 { eprintln("vm: leave") } }

	mut btstack := new_btstack()
	mut capstack := []Capture{ cap: 10 }

	mut pc := start_pc
  	for mmatch.has_more_instructions(pc) {
		instr := mmatch.instruction(pc)
    	if mmatch.debug > 9 { eprintln("pos: ${mmatch.data.pos}, Instruction: ${mmatch.rplx.instruction_str(pc)}") }

    	mmatch.stats.instr_count ++
		opcode := instr.opcode()
    	match opcode {
			// Mark S. reports that 98% of executed instructions are
			// ITestSet, IAny, IPartialCommit (in that order).  So we put
			// them first here, in case it speeds things up.  But with
			// branch prediction, it probably makes no difference.
    		.test_set {
				if mmatch.data.eof() {
					mmatch.matched = false
					break
				} else if testchar(mmatch.data.peek_byte(), mmatch.rplx.code, pc + 1) {
					mmatch.data.pos ++
				} else if btstack.len == 0 { 
					eprintln(".test_set: failure")
					mmatch.matched = false
					break
				} else {
	    			last := btstack.pop()
	    			pc = last.pc
					mmatch.data.pos = last.s
				}
    		}
			.any {
      			if !mmatch.data.eof() { 
					mmatch.data.pos ++
				} else if btstack.len == 0 {
					mmatch.matched = false
					break
				} else {
	    			pc = btstack.pop().pc
				}
    		}
    		.partial_commit {	
				btstack.last().s = mmatch.data.pos
      			pc += mmatch.addr(pc)
				continue
    		}
    		.end {
      			return MatchErrorCodes.ok
    		}
    		.giveup {
      			return MatchErrorCodes.ok
    		}
    		.ret {
      			pc = btstack.pop().pc
    		}
    		.test_any {
      			if !mmatch.data.eof() { 
					mmatch.data.pos += 1
				} else { 
					// TODO Rather then addr, may be we should call it arg1 !?!?
					// TODO We could use aux() and safe a word in the instructions
	      			pc = mmatch.addr(pc)
				}
    		}
    		.char {
				if !mmatch.data.eof() && mmatch.cmp_char(instr.ichar()) { 
					mmatch.data.pos ++
				} else if btstack.len == 0 { 
					mmatch.matched = false
					break
				} else {
	    			last := btstack.pop()
	    			pc = last.pc
					mmatch.data.pos = last.s
					continue
				}
    		}
    		.test_char {
				if mmatch.data.eof() {
					pc += mmatch.addr(pc)
					continue
				} else if mmatch.cmp_char(instr.ichar()) { 
					// ok
				} else if btstack.len == 0 { 
					mmatch.matched = false
					break
				} else {
	    			last := btstack.pop()
	    			pc = last.pc
					mmatch.data.pos = last.s
				}
    		}
    		.set {
				if mmatch.data.eof() {
					break
				} else if btstack.len == 0 { 
					break
				} else if testchar(mmatch.data.peek_byte(), mmatch.rplx.code, pc + 1) {
					mmatch.data.pos ++
				} else { 
	    			pc = btstack.pop().pc	// TODO do we need to restore input.pos?
				}
    		}
    		.behind { // TODO don't understand what it is doing
				if btstack.len == 0 { 
					break
				} else {
					mmatch.data.pos -= 1	// TODO  How far to go back?					
				}
    		}
    		.span {
      			for !mmatch.data.eof() {
	      			if !testchar(mmatch.data.peek_byte(), mmatch.rplx.code, pc + 1) { 
					  	break 
					}
					mmatch.data.pos ++
      			}
    		}
    		.jmp {
      			pc = mmatch.addr(pc)
    		}
    		.choice {
				// Determine what happens upon the next mismatch
      			btstack << BTEntry{ s: mmatch.data.pos, pc: pc + mmatch.addr(pc) }
    		}
    		.call {
      			btstack << BTEntry{ s: -1, pc: pc + 2 }
      			pc = mmatch.addr(pc)
    		}
    		.commit {
      			pc = btstack.pop().pc
    		}
    		.back_commit {
				pc = btstack.pop().pc
      			pc = mmatch.addr(pc)
    		}
    		.fail_twice {
      			btstack.pop()
			}
    		.fail {
				if btstack.len == 0 { break }
      			pc = btstack.pop().pc
      		}
    		.backref {
				capidx := instr.aux()
				cap := mmatch.captures[capidx]
    		}
    		.close_const_capture {
				mut cap := capstack.pop()
				cap.end_pos = mmatch.data.pos
				mmatch.captures << cap
				//update_capstats(pc)
    		}
    		.close_capture {
				mut cap := capstack.pop()
				cap.end_pos = mmatch.data.pos
				mmatch.captures << cap
    		}
    		.open_capture {
				capidx := instr.aux() - 1
				capname := mmatch.rplx.ktable.get(capidx)
      			capstack << Capture{ name: capname, capkind: instr.capkind(), start_pos: mmatch.data.pos }
    		}
    		.halt {	
				for capstack.len > 0 {
					capstack.pop()
				}
      			return MatchErrorCodes.ok
    		}
			else {
				panic("Illegal opcode at $pc: ${opcode}")
    		} 
		}
		pc += instr.sizei()
  	}
	return MatchErrorCodes.ok
}

fn (mut mmatch Match) vm_match(input string) ?MatchErrorCodes {
	if mmatch.debug > 0 { eprintln("vm_match: enter (debug=$mmatch.debug)") }

	// Put the input data into a buffer, so that we can track 
	// the current position (cursor)
	mmatch.data = Buffer{ data: input.bytes() }

  	err := mmatch.vm(0)?

  	mmatch.stats.total_time += 0 // tfinal - t0  // total time (includes capture processing // TODO: review 

  	return err
}
