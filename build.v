module main

// This is my own little build file

import os

fn exec(str string) {
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

// ---------------------------------------------------------
// Build the Rosie CLI tool
exec(r'..\v\v.exe rosie_cli.exe')

// ---------------------------------------------------------
// Create the rcfile.rplx, rpl_1_3.rplx and unittest.rplx files using the stage-0 parser
exec(r'rosie_cli.exe --norcfile compile -l stage_0 .\modules\rosie\rcli\rcfile.rpl origin')
exec(r'rosie_cli.exe --norcfile compile -l stage_0 .\rpl\rosie\rpl_1_3_jdo.rpl rpl_module rpl_expression')
exec(r'rosie_cli.exe --norcfile compile -l stage_0 .\modules\unittests\unittest.rpl unittest')

// ---------------------------------------------------------
// And now create repeat it with the just created rpl-1.3 parser
exec(r'rosie_cli.exe compile .\modules\rosie\rcli\rcfile.rpl origin')
exec(r'rosie_cli.exe compile .\rpl\rosie\rpl_1_3_jdo.rpl rpl_module rpl_expression')
exec(r'rosie_cli.exe compile .\modules\unittests\unittest.rpl unittest')

// ---------------------------------------------------------
// Run all the test cases, including the rpl unittests
exec(r'..\v\v.exe -cg test modules')


//res := exec('git rev-parse --short HEAD')
//git_rev := if res.exit_code == 0 { res.output.trim_space() } else { '<unknown>' }
