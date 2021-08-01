module compiler_backend_vm

import rosie.runtime as rt
import rosie.parser

//
// Please see ./modules/rosie/disassembler for an executable to disassemble *.rplx file.
// The files in ./modules/runtime/test_data/*.rplx have been compiled with rosie's
// original compiler, and we used them as starting point for the instructions to be
// generated by the compiler backend.
//
// .\modules\rosie\disassembler\disassembler.exe .\modules\rosie\runtime\test_data\simple_s00.rplx
//

fn parse_and_compile(rpl string, debug int) ? Compiler {
	mut p := parser.new_parser(data: rpl, debug: debug)?
	p.parse_binding()?
	mut c := new_compiler(p)
	c.compile("*")?
	return c
}

fn test_s00() ? {
	mut c := parse_and_compile('"abc"', 0)?
	// pc: 0, open-capture #1 's00'
  	// pc: 2, char 'a'
  	// pc: 3, char 'b'
  	// pc: 4, char 'c'
  	// pc: 5, close-capture
  	// pc: 6, end
	assert c.symbols.len() == 1
	assert c.symbols.get(0) == "*"
	assert c.code.len == 7
	assert c.code[0].opcode() == .open_capture
	assert c.code[0].aux() == 1			// symbol at pos 0
	assert c.code[2].opcode() == .char
	assert c.code[2].ichar() == `a`
	assert c.code[3].opcode() == .char
	assert c.code[3].ichar() == `b`
	assert c.code[4].opcode() == .char
	assert c.code[4].ichar() == `c`
	assert c.code[5].opcode() == .close_capture
	assert c.code[6].opcode() == .end
}

fn test_s01() ? {
	mut c := parse_and_compile('"a"+', 0)?
	// pc: 0, open-capture #1 's01'
  	// pc: 2, char 'a'
  	// pc: 3, span [(98)]		// TODO span seems large (and a bit slow) for this use case
  	// pc: 12, close-capture
  	// pc: 13, end
	assert c.symbols.len() == 1
	assert c.symbols.get(0) == "*"
	assert c.code.len == 14
	assert c.code[0].opcode() == .open_capture
	assert c.code[0].aux() == 1			// symbol at pos 0
	assert c.code[2].opcode() == .char
	assert c.code[2].ichar() == `a`
	assert c.code[3].opcode() == .span
	assert c.code.to_charset(4).is_equal(rt.new_charset_with_byte(`a`))
	assert c.code[12].opcode() == .close_capture
	assert c.code[13].opcode() == .end
}

fn test_s02() ? {
	mut c := parse_and_compile('"abc"+', 0)?
	// pc: 0, open-capture #1 's02'
  	// pc: 2, char 'a'
  	// pc: 3, char 'b'
  	// pc: 4, char 'c'
  	// pc: 5, test-char 'a' JMP to 14
  	// pc: 7, choice JMP to 14
  	// pc: 9, char 'a'
  	// pc: 10, char 'b'
  	// pc: 11, char 'c'
  	// pc: 12, partial-commit JMP to 9
  	// pc: 14, close-capture
  	// pc: 15, end
  	assert c.symbols.len() == 1
	assert c.symbols.get(0) == "*"
	assert c.code.len == 16

	assert c.code[0].opcode() == .open_capture
	assert c.code[0].aux() == 1			// symbol at pos 0
	assert c.code[2].opcode() == .char
	assert c.code[2].ichar() == `a`
	assert c.code[3].opcode() == .char
	assert c.code[3].ichar() == `b`
	assert c.code[4].opcode() == .char
	assert c.code[4].ichar() == `c`
	assert c.code[5].opcode() == .test_char
	assert c.code[5].ichar() == `a`
	assert c.code.addr(5) == 14
	assert c.code[7].opcode() == .choice
	assert c.code.addr(7) == 14
	assert c.code[9].opcode() == .char
	assert c.code[9].ichar() == `a`
	assert c.code[10].opcode() == .char
	assert c.code[10].ichar() == `b`
	assert c.code[11].opcode() == .char
	assert c.code[11].ichar() == `c`
	assert c.code[12].opcode() == .partial_commit
	assert c.code.addr(12) == 9
	assert c.code[14].opcode() == .close_capture
	assert c.code[15].opcode() == .end
}

fn test_s03() ? {
	mut c := parse_and_compile('{"a"+ "b"}', 0)?
	// pc: 0, open-capture #1 's03'
  	// pc: 2, char 'a'
  	// pc: 3, span [(98)]
  	// pc: 12, char 'b'
  	// pc: 13, close-capture
  	// pc: 14, end

  	assert c.symbols.len() == 1
	assert c.symbols.get(0) == "*"
	// c.code.disassemble(c.symbols)

	assert c.code.len == 15
	assert c.code[0].opcode() == .open_capture
	assert c.code[0].aux() == 1			// symbol at pos 0
	assert c.code[2].opcode() == .char
	assert c.code[2].ichar() == `a`
	assert c.code[3].opcode() == .span
	assert c.code.to_charset(4).is_equal(rt.new_charset_with_byte(`a`))
	assert c.code[12].opcode() == .char
	assert c.code[12].ichar() == `b`
	assert c.code[13].opcode() == .close_capture
	assert c.code[14].opcode() == .end
}

fn test_s04() ? {
	mut c := parse_and_compile('"a"*', 0)?
	// pc: 0, open-capture #1 's04'
  	// pc: 2, span [(98)]
  	// pc: 11, close-capture
  	// pc: 12, end

  	assert c.symbols.len() == 1
	assert c.symbols.get(0) == "*"
	//c.code.disassemble(c.symbols)

	assert c.code.len == 13
	assert c.code[0].opcode() == .open_capture
	assert c.code[0].aux() == 1			// symbol at pos 0
	assert c.code[2].opcode() == .span
	assert c.code.to_charset(3).is_equal(rt.new_charset_with_byte(`a`))
	assert c.code[11].opcode() == .close_capture
	assert c.code[12].opcode() == .end
}

fn test_s05() ? {
	mut c := parse_and_compile('"abc"*', 0)?
	// pc: 0, open-capture #1 's05'
  	// pc: 2, test-char 'a' JMP to 11
  	// pc: 4, choice JMP to 11
  	// pc: 6, char 'a'
  	// pc: 7, char 'b'
  	// pc: 8, char 'c'
  	// pc: 9, partial-commit JMP to 6
  	// pc: 11, close-capture
  	// pc: 12, end

  	assert c.symbols.len() == 1
	assert c.symbols.get(0) == "*"
	//c.code.disassemble(c.symbols)

	assert c.code.len == 13
	assert c.code[0].opcode() == .open_capture
	assert c.code[0].aux() == 1			// symbol at pos 0
	assert c.code[2].opcode() == .test_char
	assert c.code[2].ichar() == `a`
	assert c.code.addr(2) == 11
	assert c.code[4].opcode() == .choice
	assert c.code.addr(4) == 11
	assert c.code[6].opcode() == .char
	assert c.code[6].ichar() == `a`
	assert c.code[7].opcode() == .char
	assert c.code[7].ichar() == `b`
	assert c.code[8].opcode() == .char
	assert c.code[8].ichar() == `c`
	assert c.code[9].opcode() == .partial_commit
	assert c.code.addr(9) == 6
	assert c.code[11].opcode() == .close_capture
	assert c.code[12].opcode() == .end
}

fn test_s06() ? {
	mut c := parse_and_compile('{"a"* "b"}', 0)?
	// pc: 0, open-capture #1 's06'
  	// pc: 2, span [(98)]
  	// pc: 11, char 'b'
  	// pc: 12, close-capture
  	// pc: 13, end

  	assert c.symbols.len() == 1
	assert c.symbols.get(0) == "*"
	//c.code.disassemble(c.symbols)

	assert c.code.len == 14
	assert c.code[0].opcode() == .open_capture
	assert c.code[0].aux() == 1			// symbol at pos 0
	assert c.code[2].opcode() == .span
	assert c.code.to_charset(3).is_equal(rt.new_charset_with_byte(`a`))
	assert c.code[11].opcode() == .char
	assert c.code[11].ichar() == `b`
	assert c.code[12].opcode() == .close_capture
	assert c.code[13].opcode() == .end
}

fn test_s07() ? {
	mut c := parse_and_compile('"a"{2,4}', 0)?
	// pc: 0, open-capture #1 's07'
  	// pc: 2, char 'a'
  	// pc: 3, char 'a'
  	// pc: 4, test-char 'a' JMP to 10
  	// pc: 6, any
  	// pc: 7, test-char 'a' JMP to 10
  	// pc: 9, any
  	// pc: 10, close-capture
  	// pc: 11, end

  	assert c.symbols.len() == 1
	assert c.symbols.get(0) == "*"
	//c.code.disassemble(c.symbols)

	assert c.code.len == 12
	assert c.code[0].opcode() == .open_capture
	assert c.code[0].aux() == 1			// symbol at pos 0
	assert c.code[2].opcode() == .char
	assert c.code[2].ichar() == `a`
	assert c.code[3].opcode() == .char
	assert c.code[3].ichar() == `a`

	assert c.code[4].opcode() == .test_char
	assert c.code[4].ichar() == `a`
	assert c.code.addr(4) == 10
	assert c.code[6].opcode() == .any

	assert c.code[7].opcode() == .test_char
	assert c.code[7].ichar() == `a`
	assert c.code.addr(7) == 10
	assert c.code[9].opcode() == .any
	assert c.code[10].opcode() == .close_capture
	assert c.code[11].opcode() == .end
}

fn test_s08() ? {
	mut c := parse_and_compile('"abc"{2,4}', 0)?
	// pc: 0, open-capture #1 's08'
  	// pc: 2, char 'a'
  	// pc: 3, char 'b'
  	// pc: 4, char 'c'
  	// pc: 5, char 'a'
  	// pc: 6, char 'b'
  	// pc: 7, char 'c'
  	// pc: 8, test-char 'a' JMP to 22
  	// pc: 10, choice JMP to 22
  	// pc: 12, any aux=1 (0x1)
  	// pc: 13, char 'b'
  	// pc: 14, char 'c'
  	// pc: 15, partial-commit JMP to 17
  	// pc: 17, char 'a'
  	// pc: 18, char 'b'
  	// pc: 19, char 'c'
  	// pc: 20, commit JMP to 22
  	// pc: 22, close-capture
  	// pc: 23, end
  	assert c.symbols.len() == 1
	assert c.symbols.get(0) == "*"
	//c.code.disassemble(c.symbols)

	assert c.code.len == 24
	assert c.code[0].opcode() == .open_capture
	assert c.code[0].aux() == 1			// symbol at pos 0
	assert c.code[2].opcode() == .char
	assert c.code[2].ichar() == `a`
	assert c.code[3].opcode() == .char
	assert c.code[3].ichar() == `b`
	assert c.code[4].opcode() == .char
	assert c.code[4].ichar() == `c`
	assert c.code[5].opcode() == .char
	assert c.code[5].ichar() == `a`
	assert c.code[6].opcode() == .char
	assert c.code[6].ichar() == `b`
	assert c.code[7].opcode() == .char
	assert c.code[7].ichar() == `c`
	assert c.code[8].opcode() == .test_char
	assert c.code[8].ichar() == `a`
	assert c.code.addr(8) == 22
	assert c.code[10].opcode() == .choice
	assert c.code.addr(10) == 22
	assert c.code[12].opcode() == .any
	assert c.code[13].opcode() == .char
	assert c.code[13].ichar() == `b`
	assert c.code[14].opcode() == .char
	assert c.code[14].ichar() == `c`
	assert c.code[15].opcode() == .partial_commit
	assert c.code.addr(15) == 17
	assert c.code[17].opcode() == .char
	assert c.code[17].ichar() == `a`
	assert c.code[18].opcode() == .char
	assert c.code[18].ichar() == `b`
	assert c.code[19].opcode() == .char
	assert c.code[19].ichar() == `c`
	assert c.code[20].opcode() == .commit
	assert c.code.addr(20) == 22
	assert c.code[22].opcode() == .close_capture
	assert c.code[23].opcode() == .end
}

fn test_s09() ? {
	mut c := parse_and_compile('{"a"{2,4} "b"}', 0)?
	// pc: 0, open-capture #1 's09'
  	// pc: 2, char 'a'
  	// pc: 3, char 'a'
  	// pc: 4, test-char 'a' JMP to 10
  	// pc: 6, any aux=0 (0x0)
  	// pc: 7, test-char 'a' JMP to 10
  	// pc: 9, any aux=127 (0x7f)
  	// pc: 10, char 'b'
  	// pc: 11, close-capture
  	// pc: 12, end

  	assert c.symbols.len() == 1
	assert c.symbols.get(0) == "*"
	//c.code.disassemble(c.symbols)

	assert c.code.len == 13
	assert c.code[0].opcode() == .open_capture
	assert c.code[0].aux() == 1			// symbol at pos 0
	assert c.code[2].opcode() == .char
	assert c.code[2].ichar() == `a`
	assert c.code[3].opcode() == .char
	assert c.code[3].ichar() == `a`
	assert c.code[4].opcode() == .test_char
	assert c.code[4].ichar() == `a`
	assert c.code.addr(4) == 10
	assert c.code[6].opcode() == .any
	assert c.code[7].opcode() == .test_char
	assert c.code[7].ichar() == `a`
	assert c.code.addr(7) == 10
	assert c.code[9].opcode() == .any
	assert c.code[10].opcode() == .char
	assert c.code[10].ichar() == `b`
	assert c.code[11].opcode() == .close_capture
	assert c.code[12].opcode() == .end
}

/*
fn test_s10() ? {
	mut c := parse_and_compile('.*', 0)?
	// Wow, quite complicated: "Matches a single Unicode character encoded in UTF-8, or (failing that) a single byte"

	// pc: 0, open-capture #1 's10'
    // pc: 2, test-any aux=0 (0x0), 1=151 (0x97)
    // pc: 4, choice JMP to 153
    // pc: 6, test-set [(1-128)]
    // pc: 16, set [(1-96)(226-228)(233-239)]
    // pc: 25, partial-commit JMP to 6
    // pc: 27, test-set [(193-224)]
    // pc: 37, choice JMP to 59
    // pc: 39, set [(161-192)(227-228)]
    // pc: 48, set [(97-160)(227)(229)]
    // pc: 57, commit JMP to 151
    // pc: 59, test-set [(225-240)]
    // pc: 69, choice JMP to 100
    // pc: 71, set [(193-208)(227-228)(234)(236-237)(239)(241)(244-246)(248)(250)(252)(254-255)]
    // pc: 80, set [(97-160)(227-228)(233-239)]
    // pc: 89, set [(97-160)(227)(229)]
    // pc: 98, commit JMP to 151
    // pc: 100, test-set [(241-248)]
    // pc: 110, choice JMP to 150
    // pc: 112, set [(209-216)(227-228)(233-239)]
    // pc: 121, set [(97-160)(227-228)(234-237)(239-240)(244-245)(247)(252)(255)]
    // pc: 130, set [(97-160)(227-228)(233-239)]
    // pc: 139, set [(97-160)(227)(229)(233-235)(237)(241-244)(246-247)(252)(255)]
    // pc: 148, commit JMP to 151
    // pc: 150, any aux=15382874 (0xeab95a)
    // pc: 151, partial-commit JMP to 6
    // pc: 153, close-capture
    // pc: 154, end

  	assert c.symbols.len() == 1
	assert c.symbols.get(0) == "*"
	//c.code.disassemble(c.symbols)

	assert c.code.len == 13
	assert c.code[0].opcode() == .open_capture
	assert c.code[0].aux() == 1			// symbol at pos 0

	assert c.code[11].opcode() == .close_capture
	assert c.code[12].opcode() == .end
}
*/
/*
fn test_s11() ? {
	mut c := parse_and_compile('{"a" .*}', 0)?
	// Not much easier :(

    // pc: 0, open-capture #1 's11'
    // pc: 2, char 'a'
    // pc: 3, test-any aux=0 (0x0), 1=151 (0x97)
    // pc: 5, choice JMP to 154
    // pc: 7, test-set [(1-128)]
    // pc: 17, set [(1-96)(226-228)(234-235)(238-239)(241)(244-246)(248)(252)(255)]
    // pc: 26, partial-commit JMP to 7
    // pc: 28, test-set [(193-224)]
    // pc: 38, choice JMP to 60
    // pc: 40, set [(161-192)(227-228)(233-239)]
    // pc: 49, set [(97-160)(227)(229)]
    // pc: 58, commit JMP to 152
    // pc: 60, test-set [(225-240)]
    // pc: 70, choice JMP to 101
    // pc: 72, set [(193-208)(227-228)(233-239)]
    // pc: 81, set [(97-160)(227-228)]
    // pc: 90, set [(97-160)(227)(229)]
    // pc: 99, commit JMP to 152
    // pc: 101, test-set [(241-248)]
    // pc: 111, choice JMP to 151
    // pc: 113, set [(209-216)(227-228)(234)(236-240)(242)(244-246)(248)(252)(255)]
    // pc: 122, set [(97-160)(227-228)]
    // pc: 131, set [(97-160)(227-228)(234)]
    // pc: 140, set [(97-160)(227)(229)(233-239)]
    // pc: 149, commit JMP to 152
    // pc: 151, any aux=127 (0x7f)
    // pc: 152, partial-commit JMP to 7
    // pc: 154, close-capture
    // pc: 155, end

  	assert c.symbols.len() == 1
	assert c.symbols.get(0) == "*"
	//c.code.disassemble(c.symbols)

	assert c.code.len == 13
	assert c.code[0].opcode() == .open_capture
	assert c.code[0].aux() == 1			// symbol at pos 0

	assert c.code[11].opcode() == .close_capture
	assert c.code[12].opcode() == .end
}
*/
/*
fn test_s12() ? {
	mut c := parse_and_compile('{.* "a"}', 0)?
	// IMHO this should raise a compiler warning / error, as ".*" will consumer everything. RPL is greedy !!
	// TODO I know RPL is greedy etc., but may be the compiler could automatically translate it in the perceived meaning

    // pc: 0, open-capture #1 's12'
    // pc: 2, test-any aux=0 (0x0), 1=151 (0x97)
    // pc: 4, choice JMP to 153
    // pc: 6, test-set [(1-128)]
    // pc: 16, set [(1-96)(226-228)(233-239)]
    // pc: 25, partial-commit JMP to 6
    // pc: 27, test-set [(193-224)]
    // pc: 37, choice JMP to 59
    // pc: 39, set [(161-192)(227-228)]
    // pc: 48, set [(97-160)(227)(229)]
    // pc: 57, commit JMP to 151
    // pc: 59, test-set [(225-240)]
    // pc: 69, choice JMP to 100
    // pc: 71, set [(193-208)(227-228)]
    // pc: 80, set [(97-160)(227-228)]
    // pc: 89, set [(97-160)(227)(229)]
    // pc: 98, commit JMP to 151
    // pc: 100, test-set [(241-248)]
    // pc: 110, choice JMP to 150
    // pc: 112, set [(209-216)(227-228)]
    // pc: 121, set [(97-160)(227-228)]
    // pc: 130, set [(97-160)(227-228)(233-239)]
    // pc: 139, set [(97-160)(227)(229)(233)(235-238)(240)(242)(248)(252)(255)]
    // pc: 148, commit JMP to 151
    // pc: 150, any aux=15382874 (0xeab95a)
    // pc: 151, partial-commit JMP to 6
    // pc: 153, char 'a'
    // pc: 154, close-capture
    // pc: 155, end
}
*/
/*
fn test_s13() ? {
	mut c := parse_and_compile('{{ !"a" . }* "a"}', 0)?
    // pc: 0, open-capture #1 's13'
    // pc: 2, test-set [(1-97)(99-255)]
    // pc: 12, test-char 'a' JMP to 15
    // pc: 14, fail
    // pc: 15, test-set [(1-128)]
    // pc: 25, set [(1-96)(229)]
    // pc: 34, jmp to 2
    // pc: 36, test-set [(193-224)]
    // pc: 46, choice JMP to 68
    // pc: 48, set [(161-192)(227-228)]
    // pc: 57, set [(97-160)(227)(229)]
    // pc: 66, commit JMP to 2
    // pc: 68, test-set [(225-240)]
    // pc: 78, choice JMP to 109
    // pc: 80, set [(193-208)(227-228)(233-239)]
    // pc: 89, set [(97-160)(227-228)]
    // pc: 98, set [(97-160)(227)(229)(233-239)]
    // pc: 107, commit JMP to 2
    // pc: 109, test-set [(241-248)]
    // pc: 119, choice JMP to 159
    // pc: 121, set [(209-216)(227-228)(234)]
    // pc: 130, set [(97-160)(227-228)(233-239)]
    // pc: 139, set [(97-160)(227-228)(233-234)(236-245)(247)(252)(255)]
    // pc: 148, set [(97-160)(227)(229)(233-239)]
    // pc: 157, commit JMP to 2
    // pc: 159, any aux=0 (0x0)
    // pc: 160, jmp to 2
    // pc: 162, char 'a'
    // pc: 163, close-capture
    // pc: 164, end
}
*/
/*
fn test_s14() ? {
	mut c := parse_and_compile('find:"a"', 0)?

    // pc: 0, open-capture #5 's14'
    // pc: 2, call JMP to 6
    // pc: 4, jmp to 179
    // pc: 6, call JMP to 11
    // pc: 8, jmp to 174
    // pc: 10, ret
    // pc: 11, test-set [(1-97)(99-255)]
    // pc: 21, choice JMP to 173
    // pc: 23, test-char 'a' JMP to 26
    // pc: 25, fail
    // pc: 26, test-set [(1-128)]
    // pc: 36, set [(1-96)(226-228)(233-239)]
    // pc: 45, partial-commit JMP to 23
    // pc: 47, test-set [(193-224)]
    // pc: 57, choice JMP to 79
    // pc: 59, set [(161-192)(227-228)(233)]
    // pc: 68, set [(97-160)(227)(229)(233-239)]
    // pc: 77, commit JMP to 171
    // pc: 79, test-set [(225-240)]
    // pc: 89, choice JMP to 120
    // pc: 91, set [(193-208)(227-228)]
    // pc: 100, set [(97-160)(227-228)]
    // pc: 109, set [(97-160)(227)(229)]
    // pc: 118, commit JMP to 171
    // pc: 120, test-set [(241-248)]
    // pc: 130, choice JMP to 170
    // pc: 132, set [(209-216)(227-228)]
    // pc: 141, set [(97-160)(227-228)]
    // pc: 150, set [(97-160)(227-228)(233-255)]
    // pc: 159, set [(97-160)(227)(229)(233)(236-237)(239)(241-242)(246)(249)(252)(255)]
    // pc: 168, commit JMP to 171
    // pc: 170, any aux=15416508 (0xeb3cbc)
    // pc: 171, partial-commit JMP to 23
    // pc: 173, ret
    // pc: 174, open-capture #4 'find.*'
    // pc: 176, char 'a'
    // pc: 177, close-capture
    // pc: 178, ret
    // pc: 179, close-capture
    // pc: 180, end
}
*/
/*
fn test_s15() ? {
	mut c := parse_and_compile('"a" "b"', 0)?
	// word boundary is another quite complicated thing :(

    // pc: 0, open-capture #1 's15'
    // pc: 2, char 'a'
    // pc: 3, test-set [(10-14)(33)]
    // pc: 13, set [(1)(225)(227-228)(235-238)(240)(243-246)(249-250)(252)(254-255)]
    // pc: 22, span [(10-14)(33)]
    // pc: 31, jmp to 143
    // pc: 33, test-set [(49-58)(66-91)(98-123)]
    // pc: 43, choice JMP to 70
    // pc: 45, choice JMP to 58
    // pc: 47, behind aux=1 (0x1)
    // pc: 48, set [(17-26)(34-59)(66-91)(225)(227)(233-239)]
    // pc: 57, fail-twice
    // pc: 58, set [(17-26)(34-59)(66-91)(228)(233)]
    // pc: 67, behind aux=1 (0x1)
    // pc: 68, commit JMP to 143
    // pc: 70, test-set [(34-48)(59-65)(92-97)(124-127)]
    // pc: 80, set [(2-16)(27-33)(60-65)(92-95)(228)(233)]
    // pc: 89, behind aux=1 (0x1)
    // pc: 90, jmp to 143
    // pc: 92, choice JMP to 106
    // pc: 94, behind aux=1 (0x1)
    // pc: 95, set [(2-16)(27-33)(60-65)(92-95)(227)(229)(233)(237-238)(242)(244-245)(248)(252)(255)]
    // pc: 104, commit JMP to 143
    // pc: 106, choice JMP to 131
    // pc: 108, test-set [(10-14)(33)]
    // pc: 118, fail
    // pc: 119, behind aux=1 (0x1)
    // pc: 120, set [(1)(227)(229)(233-239)]
    // pc: 129, commit JMP to 143
    // pc: 131, choice JMP to 138
    // pc: 133, test-any aux=0 (0x0), 1=3 (0x3)
    // pc: 135, fail
    // pc: 136, commit JMP to 143
    // pc: 138, choice JMP to 143
    // pc: 140, behind aux=1 (0x1)
    // pc: 141, any aux=127 (0x7f)
    // pc: 142, fail-twice
    // pc: 143, char 'b'
    // pc: 144, close-capture
    // pc: 145, end
}
*/
fn test_s16() ? {
	mut c := parse_and_compile('"a" / "bc"', 0)?
	// word boundary is another quite complicated thing :(

    // pc: 0, open-capture #1 's16'
    // pc: 2, test-char 'a' JMP to 7
    // pc: 4, any
    // pc: 5, jmp to 9
    // pc: 7, char 'b'
    // pc: 8, char 'c'
    // pc: 9, close-capture
    // pc: 10, end

  	assert c.symbols.len() == 1
	assert c.symbols.get(0) == "*"
	c.code.disassemble(c.symbols)

	assert c.code.len == 11
	assert c.code[0].opcode() == .open_capture
	assert c.code[0].aux() == 1			// symbol at pos 0
	assert c.code[2].opcode() == .test_char
	assert c.code[2].ichar() == `a`
	assert c.code.addr(2) == 7
	assert c.code[4].opcode() == .any
	assert c.code[5].opcode() == .jmp
	assert c.code.addr(5) == 9
	assert c.code[7].opcode() == .test_char
	assert c.code[7].ichar() == `b`
	assert c.code[8].opcode() == .test_char
	assert c.code[8].ichar() == `c`
	assert c.code[9].opcode() == .close_capture
	assert c.code[10].opcode() == .end
}
