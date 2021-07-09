module rosie

//  -*- Mode: C; -*-                                                         
//                                                                           
//  vm.h                                                                     
//                                                                           
//  © Copyright Jamie A. Jennings 2018.                                      
//  Portions Copyright 2007, Lua.org & PUC-Rio (via lpeg)                    
//  LICENSE: MIT License (https://opensource.org/licenses/mit-license.html)  
//  AUTHOR: Jamie A. Jennings                                                


fn (mut mmatch Match) vm(start_pc int, start_pos int) bool {
	mut btstack := []BTEntry{ cap: 10 }
	btstack << BTEntry{ capidx: 0, pc: mmatch.rplx.code.len, pos: 0 }	// end of instructions => return from VM

	mut pc := start_pc
	mut pos := start_pos
	mut capidx := 0		// Caps are added to a list, but it is a tree. capidx points at the current entry in the list. 

	if mmatch.debug > 0 { eprint("\nvm: enter: pc=$pc, pos=$pos, input='$mmatch.input'") }
	defer { if mmatch.debug > 0 { eprint("\nvm: leave: pc=$pc, pos=$pos") } }

  	for mmatch.has_more_instructions(pc) {
		instr := mmatch.instruction(pc)
    	if mmatch.debug > 9 { eprint("\npos: ${pos}, bt.len=${btstack.len}, ${mmatch.rplx.instruction_str(pc)}") }

    	mmatch.stats.instr_count ++
		opcode := instr.opcode()
    	match opcode {
    		.test_set {
				if !mmatch.testchar(pos, pc + 2) {
					pc = mmatch.addr(pc)
					if mmatch.debug > 2 { eprint(" => failed: pc=$pc") }
					continue
				}
    		}
			.any {
      			if !mmatch.eof(pos) { 
					pos ++
				} else {
					x := btstack.pop()
					pos = x.pos
					pc = x.pc
					continue
				}
    		}
    		.test_any {
      			if mmatch.eof(pos) { 
	      			pc = mmatch.addr(pc)
					if mmatch.debug > 2 { eprint(" => failed: pc=$pc") }
					continue
				}
    		}
    		.char {
				if mmatch.cmp_char(pos, instr.ichar()) { 
					pos ++
				} else {
					if mmatch.debug > 2 { eprint(" => failed") }
					x := btstack.pop()
					pos = x.pos
					pc = x.pc
					continue
				}
    		}
    		.test_char {
				if !mmatch.cmp_char(pos, instr.ichar()) { 
					pc = mmatch.addr(pc)
					if mmatch.debug > 2 { eprint(" => failed: pc=$pc") }
					continue
				}
    		}
    		.set {
				if mmatch.testchar(pos, pc + 1) {
					pos ++
				} else {
					x := btstack.pop()
					pos = x.pos
					pc = x.pc
					continue
				}
    		}
    		.partial_commit {	
				if mmatch.debug > 2 { eprint(" '${mmatch.captures[capidx].name}'") }
				btstack.last().pos = pos
      			pc = mmatch.addr(pc)
				continue
    		}
    		.span {
      			for mmatch.testchar(pos, pc + 1) { pos ++ }
    		}
    		.jmp {
      			pc = mmatch.addr(pc)
				continue
    		}
    		.choice {	// stack a choice; next fail will jump to 'offset' 
				btstack << BTEntry{ capidx: capidx, pc: mmatch.addr(pc), pos: pos }
    		}
    		.call {		// call rule at 'offset' 
				btstack << BTEntry{ capidx: capidx, pc: pc + instr.sizei(), pos: pos }
				pc = mmatch.addr(pc)
				continue
    		}
    		.commit {	// pop choice and jump to 'offset' 
				if mmatch.debug > 2 { eprint(" '${mmatch.captures[capidx].name}'") }
				capidx = btstack.pop().capidx
				pc = mmatch.addr(pc)
				continue
    		}
    		.back_commit {	// "fails" but jumps to its own 'offset' 
				panic("The 'back_commit' byte code is not implemented")
				if mmatch.debug > 2 { eprint(" '${mmatch.captures[capidx].name}'") }
				capidx = btstack.pop().capidx
				pc = mmatch.addr(pc)
				continue
    		}
    		.close_capture, .close_const_capture {	// push const close capture and index onto cap list 
				mut cap := &mmatch.captures[capidx]
				if mmatch.debug > 2 { eprint(" '${cap.name}'") }
				cap.end_pos = pos
				cap.matched = true
				capidx = cap.parent
    		}
    		.open_capture {		// start a capture (kind is 'aux', key is 'offset') 
				capname := mmatch.rplx.ktable.get(instr.aux() - 1)
				level := if mmatch.captures.len == 0 { 0 } else { mmatch.captures[capidx].level + 1 }
      			mmatch.captures << Capture{ name: capname, matched: false, start_pos: pos, level: level, parent: capidx }
				capidx = mmatch.captures.len - 1
    		}
    		.behind {
				pos -= instr.aux()
				if pos < 0 {
					x := btstack.pop()
					pos = x.pos
					pc = x.pc
					continue
				}
    		}
    		.fail_twice {	// pop one choice from stack and then fail 
				btstack.pop()

				x := btstack.pop()
				pos = x.pos
				pc = x.pc
				continue
			}
    		.fail {			// pop stack (pushed on choice), jump to saved offset 
				x := btstack.pop()
				pos = x.pos
				pc = x.pc
				continue
      		}
    		.ret {
				pc = btstack.pop().pc
				continue
    		}
    		.end {
      			break
    		}
    		.backref {	// TODO
				panic("'backref' byte code instruction is not yet implemented")
				_ := mmatch.captures[instr.aux()]
    		}
			.giveup {
				panic("'giveup is not implemented")
			} 
    		.halt {		// abnormal end (abort the match) 
				break
    		}
			else {
				panic("Illegal opcode at $pc: ${opcode}")
    		} 
		}
		pc += instr.sizei()
  	}

	if mmatch.captures.len == 0 { panic("Expected to find at least one Capture") }

	mmatch.matched = mmatch.captures[0].matched
	mmatch.pos = if mmatch.matched { mmatch.captures[0].end_pos } else { start_pos }

	return mmatch.matched
}

// can't use match() as match is a reserved word in V-lang
fn (mut mmatch Match) vm_match(input string) bool {
	if mmatch.debug > 0 { eprint("vm_match: enter (debug=$mmatch.debug)") }

	defer {
	  	mmatch.stats.total_time += 0 // tfinal - t0  // total time (includes capture processing // TODO: review 
		if mmatch.debug > 2 { eprintln("\nmatched: $mmatch.matched, pos=$mmatch.pos, captures: $mmatch.captures") }
	}
	
	mmatch.input = input
  	return mmatch.vm(0, 0)
}
