module main

// This is my own little build file

import os

fn exec(str string) {
	eprintln("-".repeat(70))
	eprintln("EXEC: $str")
	args := str.split(" ")
	mut cmd := os.new_process(args[0])
	cmd.set_args(args[1..])
	cmd.set_redirect_stdio()
	cmd.run()
	for cmd.is_alive() {
		line := cmd.stdout_read()
		if line.len > 0 {
			print('STDOUT: $line')
		}

		line_err := cmd.stderr_read()
		if line_err.len > 0 {
			print('STDERR: $line_err')
		}
	}

	if cmd.code > 0 {
		println('ERROR:')
		println(cmd)
		// println(cmd.stderr_read())
	}
}

fn create_if_not_exist(fname string) ? {
	if os.is_file(fname) == false {
		os.write_file(fname, "")?
	}
}

// ---------------------------------------------------------

const rcfile_rpl = r".\modules\rosie\rcli\rcfile.rpl"
const unittest_rpl = r".\modules\rosie\unittests\unittest.rpl"
const rpl_1_3_rpl = r".\rpl\rosie\rpl_1_3_jdo.rpl"

create_if_not_exist(rcfile_rpl + "x")?
create_if_not_exist(unittest_rpl + "x")?
create_if_not_exist(rpl_1_3_rpl + "x")?

// Build the Rosie CLI tool
exec(r'..\v\v.exe rosie_cli.v')

// ---------------------------------------------------------
// Create the rcfile.rplx, rpl_1_3.rplx and unittest.rplx files using the stage-0 parser
exec('rosie_cli.exe --norcfile compile -l stage_0 $rcfile_rpl options')
exec('rosie_cli.exe --norcfile compile -l stage_0 $rpl_1_3_rpl rpl_module rpl_expression')
exec('rosie_cli.exe --norcfile compile -l stage_0 $unittest_rpl unittest')

// ---------------------------------------------------------
// And now create repeat it with the just created rpl-1.3 parser
exec('rosie_cli.exe compile $rcfile_rpl options')
exec('rosie_cli.exe compile $rpl_1_3_rpl rpl_module rpl_expression')
exec('rosie_cli.exe compile $unittest_rpl unittest')

// ---------------------------------------------------------
// Run all the test cases, including the rpl unittests
//exec(r'..\v\v.exe -cg test modules')

//res := exec('git rev-parse --short HEAD')
//git_rev := if res.exit_code == 0 { res.output.trim_space() } else { '<unknown>' }
/* */