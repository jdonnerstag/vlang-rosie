module vm_v2

import os
import rosie.runtimes.v2 as rt


fn prepare_test(rpl string, name string, debug int) ? &rosie.Rplx {
	eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
	rplx := parse_and_compile(rpl: rpl, name: name, debug: debug, unit_test: false)?
	if debug > 0 { rplx.disassemble() }
	return rplx
}

fn test_create_rplx() ? {
	rplx := prepare_test('"ab"', "*", 0)?

	// Note: On Windows this file will be opened in TEXT mode. Which is why we close
	// it again, and just leverage the file name
	//fname := os.join_path(os.temp_dir(), "temp.rplx")
	fname := os.join_path(os.temp_dir(), "temp.rplx")
	rplx.save(fname, true)?

	r2 := rosie.Rplx_load(fname)?
}
/* */