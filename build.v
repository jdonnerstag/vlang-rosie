module main

// This is my own little build file

import os
import time 

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

struct RplFile {
	fname string
	entrypoints []string
}

// ---------------------------------------------------------

const vexe = r"..\v\v.exe"

// All the RPL files, which we want to build
const rpl_files = [
	RplFile{ fname: r".\modules\rosie\rcli\rcfile.rpl", entrypoints: ["options"] }
	RplFile{ fname: r".\modules\rosie\unittests\unittest.rpl", entrypoints: ["unittest"] }
	RplFile{ fname: r".\rpl\rosie\rpl_1_3_jdo.rpl", entrypoints: ["rpl_module", "rpl_expression"] }
]

// Cleanup, to start from very beginning.
// Requires "-c" command line option
if os.args.len > 1 && os.args[1] == "-c" {
	for rpl in rpl_files {
		if os.is_file(rpl.fname) {
			fname := rpl.fname + "x"
			eprintln("Delete file: $fname")
			os.rm(fname)?
		} 
	}
}

// $embed_file() requires a file, even if its empty.
// load_rplx() has been updated to handle empty rplx file gracefully.
for rpl in rpl_files {
	create_if_not_exist(rpl.fname + "x")?
}

// Build the Rosie CLI tool
exec('$vexe rosie_cli.v')

// Create the rplx files using the stage-0 parser
mut cmd := "rosie_cli.exe --norcfile compile -l stage_0"
for rpl in rpl_files {
	exec('$cmd $rpl.fname ${rpl.entrypoints.join(" ")}')
}

// On Win10 I occassionally have issue. Probably in combination with 
// anti-virus not yet being finished. Almost always it works, when I 
// just repeat the command.
time.sleep(1 * time.second)

// And now repeat it with the just created rpl-1.3 parser
cmd = "rosie_cli.exe compile"
for rpl in rpl_files {
	exec('$cmd $rpl.fname ${rpl.entrypoints.join(" ")}')
}

// ---------------------------------------------------------
// Run all the test cases, including the rpl unittests
//exec(r'..\v\v.exe -cg test modules')

//res := exec('git rev-parse --short HEAD')
//git_rev := if res.exit_code == 0 { res.output.trim_space() } else { '<unknown>' }

eprintln("-".repeat(70))
eprintln("Finished")
/* */