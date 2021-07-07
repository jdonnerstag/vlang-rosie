module rosie

//  -*- Mode: C; -*-                                                         
//                                                                           
//  vm.h                                                                     
//                                                                           
//  © Copyright Jamie A. Jennings 2018.                                      
//  Portions Copyright 2007, Lua.org & PUC-Rio (via lpeg)                    
//  LICENSE: MIT License (https://opensource.org/licenses/mit-license.html)  
//  AUTHOR: Jamie A. Jennings                                                


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
fn (mut mmatch Match) vm(start_pc int, start_pos int) ?(bool, int) {
	mut capstack := []Capture{ cap: 5 }
	mut pc := start_pc
	mut pos := start_pos
	mut committed_pos := pos
	mut failed := false

	if mmatch.debug > 0 { eprintln("vm: enter: pc=$pc, pos=$pos, input='$mmatch.input'") }
	defer { if mmatch.debug > 0 { eprintln("vm: leave: pc=$pc, pos=$pos, committed_pos=$committed_pos") } }

  	for mmatch.has_more_instructions(pc) {
		instr := mmatch.instruction(pc)
    	if mmatch.debug > 9 { eprintln("pos: ${pos}, failed=$failed, Instruction: ${mmatch.rplx.instruction_str(pc)}") }

    	mmatch.stats.instr_count ++
		opcode := instr.opcode()
    	match opcode {
			// Mark S. reports that 98% of executed instructions are
			// ITestSet, IAny, IPartialCommit (in that order).  So we put
			// them first here, in case it speeds things up.  But with
			// branch prediction, it probably makes no difference.
			// Juergen: I think there are other inefficiencies in the misalignment to 32bit, 
			// byte code, charset etc. causing more delays.
    		.test_set {
				if !mmatch.testchar(pos, pc + 2) {
					pc = mmatch.addr(pc)
					eprintln("fail: pc=$pc")
					continue
				}
    		}
			.any {
      			if !mmatch.eof(pos) { 
					pos ++
				} else {
					return true, committed_pos
				}
    		}
    		.partial_commit {	
				committed_pos = pos
      			pc = mmatch.addr(pc)
				continue
    		}
    		.end {
      			return failed, pos
    		}
    		.giveup {	// TODO Not sure it is still needed
      			return failed, pos
    		}
    		.ret {
				return failed, pos
    		}
    		.test_any {
      			if mmatch.eof(pos) { 
	      			pc = mmatch.addr(pc)
					eprintln("fail: pc=$pc")
					continue
				}
    		}
    		.char {
				if mmatch.cmp_char(pos, instr.ichar()) { 
					pos ++
				} else {
					eprintln("failed")
					return true, committed_pos
				}
    		}
    		.test_char {
				if !mmatch.cmp_char(pos, instr.ichar()) { 
					pc = mmatch.addr(pc)
					eprintln("fail: pc=$pc")
					continue
				}
    		}
    		.set {
				if mmatch.testchar(pos, pc + 1) {
					pos ++
				} else {
					return true, committed_pos 
				}
    		}
    		.behind { // TODO don't understand what it is doing
				/*
				if btstack.len == 0 { 
					break
				} else {
					mmatch.data.pos -= 1	// TODO  How far to go back?					
				}
				*/
    		}
    		.span {
      			for mmatch.testchar(pos, pc + 1) { pos ++ }
    		}
    		.jmp {
      			pc = mmatch.addr(pc)
				continue
    		}
    		.choice {
				_, pos = mmatch.vm(pc + instr.sizei(), pos)?
				pc = mmatch.addr(pc)
				continue
    		}
    		.call {
				failed, pos = mmatch.vm(mmatch.addr(pc), pos)?
    		}
    		.commit {
				committed_pos = pos
				return false, pos
    		}
    		.back_commit {
				committed_pos = pos
				return false, pos
    		}
    		.fail_twice {
      			return true, committed_pos
			}
    		.fail {
				return failed, committed_pos
      		}
    		.backref {
				capidx := instr.aux()
				cap := mmatch.captures[capidx]
    		}
    		.close_const_capture {
				if !failed {
					committed_pos = pos
					mut cap := capstack.pop()
					cap.end_pos = pos
					mmatch.captures << cap
				}
    		}
    		.close_capture {
				if !failed {
					committed_pos = pos
					mut cap := capstack.pop()
					cap.end_pos = pos
					mmatch.captures << cap
				}
    		}
    		.open_capture {
				capidx := instr.aux() - 1
				capname := mmatch.rplx.ktable.get(capidx)
      			capstack << Capture{ name: capname, capkind: instr.capkind(), start_pos: pos }
    		}
    		.halt {	
      			return none
    		}
			else {
				panic("Illegal opcode at $pc: ${opcode}")
    		} 
		}
		pc += instr.sizei()
  	}
	return true, pos
}

fn (mut mmatch Match) vm_match(input string) ? {
	if mmatch.debug > 0 { eprintln("vm_match: enter (debug=$mmatch.debug)") }

	defer {
	  	mmatch.stats.total_time += 0 // tfinal - t0  // total time (includes capture processing // TODO: review 
	}
	
	mmatch.input = input

  	failed, pos := mmatch.vm(0, 0)?

  	mmatch.matched = !failed
	mmatch.pos = pos
}
