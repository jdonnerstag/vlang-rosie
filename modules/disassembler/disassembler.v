module disassembler

import runtime as rt

//  -*- Mode: C/l; -*-
//                                                                           
//  dis.c                                                                    
//                                                                           
//  © Copyright Jamie A. Jennings 2018.                                      
//  Portions Copyright 2007, Lua.org & PUC-Rio (via lpeg)                    
//  LICENSE: MIT License (https://opensource.org/licenses/mit-license.html)  
//  AUTHOR: Jamie A. Jennings                                                

/* ------------------------------------------------------------------------------------------------------------- */

// TODO to be implemented
fn testchar(st byteptr, i int) bool {
    return true
}

/* TEMP: Branch aotcomp1 has a newer version of these print functions,
   but we can't use those here because this branch has an older
   revision of the ktable structure (and probably the instruction
   encodings, too). 
*/
fn print_charset(st byteptr) string {
    mut str := "["
    mut i := 0
    for i <= C.UCHAR_MAX {
        first := i
        for testchar(st, i) && i <= C.UCHAR_MAX { i++ }

        if (i - 1) == first { /* unary range? */
            str += "(${first:02x})"
        } else if (i - 1) > first {  /* non-empty range? */
            str += "(${first:02x}-${i - 1:02x})"
        }
        i ++
    }
    str += "]"
    return str
}

// TODO Move to VM later on
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

fn print_capkind(kind int) {
    print(capture_name(kind))
}

fn print_jmp(op &rt.Instruction, p &rt.Instruction) {
    target := unsafe { int(p + (p + 1).offset - op) }
    print("JMP to $target")
}

// TODO to be implemented
fn opcode_name(x int) string {
    return "test"
}

/* Print instructions with their absolute addresses, showing jump
 * destinations with their relative addresses and also the computed
 * target addresses.
 */
fn print_instruction(op &rt.Instruction, p &rt.Instruction) {
    pos := unsafe { i64(p - op) }
    name := opcode_name(opcode(p))
    print("${pos:4}  $name")
    match (opcode(p)) {
        IChar { 
            print("'${aux(p)}'") 
        }
        ITestChar { 
            print("'${aux(p)}'")
            printjmp(op, p)
        }
        IOpenCapture {
            print_capkind(addr(p))
            print(" #${aux(p)}")
        }
        ISet {
            println(print_charset(unsafe { (p + 1).buff } ))
        }
        ITestSet {
            println(print_charset(unsafe { (p + 2).buff } ))
            printjmp(op, p)
        }
        ISpan {
            println(print_charset(unsafe { (p + 1).buff } ))
        }
        IOpenCall {
            print("-> ${addr(p)}")
        }
        IBehind {
            print("#${aux(p)}")
        }
        IJmp, ICall, ICommit, IChoice, IPartialCommit, IBackCommit, ITestAny {
            printjmp(op, p)
        }
    }
    println()
}

/* TODO: move this to a more appropriate source code file */
fn walk_instructions(
        p &rt.Instruction,
		codesize int,
		operation fn (op &rt.Instruction, p &rt.Instruction, context voidptr),
		context voidptr) {

    Instruction *op = p
    n := codesize
    for p < (op + n) {
        operation(op, p, context)
        p += sizei(p)
    }
}

fn print_instructions(p &rt.Instruction, int codesize) {
    walk_instructions(p, codesize, &print_instruction, NULL)
}

/* ------------------------------------------------------------------------------------------------------------- */

fn print_usage_and_exit(progname string) {
    println("Usage: $progname [-k] [-i] [-s] <rplx_file>")
    println("  -k: print ktable (symbol table")
    println("  -i: print instruction vector")
    println("  -s: print summary")
    println("")

    exit(-1)
}

fn validate_args() ? {
    for i, s in os.args {
        if s.starts_with("-") {
            if s.len != 2 {
                return error("Invalid argument: '$s'")
            } else if "kis".contains(s[1]) == false {
                return error("Invalid argument: '$s'")
            }
        } else {
            if (i + 1) != os.args {
                return error("Invalid argument: '$s'")
            }
        }
    }
}

fn has_flag(name string) bool {
    for s in os.args {
        if s.starts_with("-") == false { break }
        if s == name { return true }
    }
    return false
}

fn get_filename() ?string {
    for s in os.args {
        if s.starts_with("-") == false { 
            return s
        }
    }
    return none
}

fn main() {
    validate_args() or { print_usage_and_exit(os.args[0]) }

    mut kflag := has_flag("-k")
    mut iflag := has_flag("-i")
    mut sflag := has_flag("-s")
    filename := get_filename() or { print_usage_and_exit(os.args[0]) }

    if !kflag && !iflag && !sflag { 
        /* default is -kis */
        kflag = true
        iflag = true
        sflag = true 
    }

    println("File: $filename")
    println("")

    rplx := load_rplx(filename,  0)?
    if (kflag) {
        println("Symbol table:")
        print_ktable(rplx.ktable)
        println("")
    }
    if (iflag) {
        println("Code:")
        print_instructions(rplx.code)
        println("")
    }
    if (sflag) {
        println("Codesize: ${rplx.code.len} instructions, ${rplx.code.len * sizeof(Instruction)} bytes")
        println("Symbols: $rplx.ktable.elems symbols in a block of XYZ bytes")
        println("")
    }
}
