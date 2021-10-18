module cli

import os
import cli
import rosie.unittests

pub fn cmd_test(cmd cli.Command) ? {
	init_rosie_with_cmd(cmd) ?

	files := cmd.args

	mut count := 0
	for f in files {
		count += test_files(f) ?
	}

	println('-'.repeat(80))
	println('Finished testing: $count files')
}

pub fn test_files(fpath string) ?int {
	mut count := 0

	if os.is_dir(fpath) {
		files := os.walk_ext(fpath, 'rpl')
		for f in files {
			count += test_files(f) ?
		}
	} else if fpath.contains('*') {
		files := os.glob(fpath) ?
		for f in files {
			count += test_files(f) ?
		}
	} else if os.is_file(fpath) {
		mut f := unittests.read_file(fpath) ?
		f.run_tests(0) or { eprintln(err.msg) }
		count += 1
	} else {
		return error("ERROR: Is not a directory or file: '$fpath'")
	}

	return count
}
