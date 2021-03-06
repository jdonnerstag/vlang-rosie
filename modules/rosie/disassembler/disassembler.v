module main

import os
import rosie.runtimes.v1 as rt
// *.rplx files are only supported with V1

fn print_usage_and_exit(progname string, msg string) {
	if msg.len > 0 {
		println('\nERROR: $msg\n')
	}

	println('Usage: $progname [-k] [-i] [-s] <rplx_file>')
	println('  -k: print symbols (symbol table')
	println('  -i: print instruction vector')
	println('  -s: print summary')
	println('')

	exit(-1)
}

fn validate_args() ? {
	for i, s in os.args {
		if i == 0 {
			continue
		}
		if s.starts_with('-') {
			if s.len != 2 {
				return error("Invalid argument: '$s'")
			} else if (s[1] in 'kis'.bytes()) == false {
				return error("Invalid argument: '$s'")
			}
		} else {
			if (i + 1) != os.args.len {
				return error("Invalid argument: '$s'")
			}
		}
	}
}

fn has_flag(name string) bool {
	for s in os.args {
		if s.starts_with('-') == false {
			break
		}
		if s == name {
			return true
		}
	}
	return false
}

fn get_filename() ?string {
	for i, s in os.args {
		if i > 0 && s.starts_with('-') == false {
			return s
		}
	}
	return none
}

fn main() {
	validate_args() or { print_usage_and_exit(os.args[0], err.msg) }

	mut kflag := has_flag('-k')
	mut iflag := has_flag('-i')
	mut sflag := has_flag('-s')
	filename := get_filename() or {
		print_usage_and_exit(os.args[0], err.msg)
		return
	}

	if !kflag && !iflag && !sflag {
		// default is -kis
		kflag = true
		iflag = true
		sflag = true
	}

	disassemble_file(filename, kflag, iflag, sflag) ?
}

pub fn disassemble_file(filename string, kflag bool, iflag bool, sflag bool) ? {
	if !kflag && !iflag && !sflag {
		return error("ERROR: at least one of the flag must be true. A good option is make them all 'true'")
	}

	println('File: $filename')
	println('')

	rplx := rt.load_rplx(filename, 0) ?
	if kflag {
		println(rplx.symbols)
	}

	if iflag {
		println('Code:')
		rplx.code.disassemble(rplx.symbols)
		println('')
	}

	if sflag {
		println('Codesize: $rplx.code.len instructions, ${rplx.code.len * int(sizeof(rt.Slot))} bytes')
		println('Symbols: $rplx.symbols.symbols.len symbol(s) in a block of XYZ bytes')
		println('')
	}
}
