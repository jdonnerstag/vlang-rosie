module compiler_backend_vm

import rosie.parser

//
// Please see ./modules/rosie/disassembler for an executable to disassemble *.rplx file.
// The files in ./modules/runtime/test_data/*.rplx have been compiled with rosie's
// original compiler, and we used them as starting point for the instructions to be
// generated by the compiler backend.
//
fn test_new_compiler() ? {
	mut p := parser.new_parser(data: '"abc"', debug: 0)?
	// pc: 0, open-capture #1 's00'
  	// pc: 2, char 'a'
  	// pc: 3, char 'b'
  	// pc: 4, char 'c'
  	// pc: 5, close-capture
  	// pc: 6, end
	p.parse_binding(0)?
	mut c := new_compiler(p)
	c.compile("*")?
	assert c.symbols.len() == 1
	assert c.symbols.get(0) == "*"
	assert c.code.len == 7
	assert c.code[0].opcode() == .open_capture
	assert c.code[1].int() == 0			// symbol at pos 0
	assert c.code[2].opcode() == .char
	assert c.code[2].ichar() == `a`
	assert c.code[3].opcode() == .char
	assert c.code[3].ichar() == `b`
	assert c.code[4].opcode() == .char
	assert c.code[4].ichar() == `c`
	assert c.code[5].opcode() == .close_capture
	assert c.code[6].opcode() == .end
}