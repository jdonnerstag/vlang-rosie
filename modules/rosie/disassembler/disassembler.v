module disassembler

import runtime as rt

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
        rplx.code.disassemble(rplx.ktable)
        println("")
    }

    if (sflag) {
        println("Codesize: ${rplx.code.len} instructions, ${rplx.code.len * sizeof(Instruction)} bytes")
        println("Symbols: $rplx.ktable.elems symbols in a block of XYZ bytes")
        println("")
    }
}
