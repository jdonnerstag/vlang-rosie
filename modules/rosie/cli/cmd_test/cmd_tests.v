module cmd_test

import os
import rosie.unittests
import rosie.cli.core


pub struct CmdTest {}

pub fn (c CmdTest) run(main core.MainArgs) ? {
    files := main.cmd_args
    if files.len < 2 {
        return error("ERROR: At leat one rpl-file name must follow the 'test' sub-command")
    }

    mut count := 0
    for f in main.cmd_args[1 ..] {
        count += c.test_files(f)?
    }

    println("-".repeat(80))
    println("Finished testing: $count files")
}

pub fn (c CmdTest) test_files(fpath string) ? int {
    mut count := 0

    if os.is_dir(fpath) {
        files := os.walk_ext(fpath, "rpl")
        for f in files { count += c.test_files(f)? }
    } else if fpath.contains("*") {
        files := os.glob(fpath)?
        for f in files { count += c.test_files(f)? }
    } else if os.is_file(fpath) {
        mut f := unittests.read_file(fpath)?
        f.run_tests(0) or { eprintln(err.msg) }
        count += 1
    } else {
        return error("ERROR: Is not a directory or file: '$fpath'")
    }

    return count
}
