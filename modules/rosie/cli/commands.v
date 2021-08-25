module cli

pub struct CmdVersion {
pub:
    name string = "version"
pub mut:
    x string
}

pub fn (c CmdVersion) read_args(args []string) {}
pub fn (c CmdVersion) run() { println(typeof(c).name) }

pub struct CmdConfig {
pub:
    name string = "config"
pub mut:
    x string
}

pub fn (c CmdConfig) read_args(args []string) {}
pub fn (c CmdConfig) run() { println(typeof(c).name) }

pub struct CmdList {
pub:
    name string = "list"
pub mut:
    x string
}

pub fn (c CmdList) read_args(args []string) {}
pub fn (c CmdList) run() { println(typeof(c).name) }

pub struct CmdGrep {
pub:
    name string = "grep"
pub mut:
    x string
}

pub fn (c CmdGrep) read_args(args []string) {}
pub fn (c CmdGrep) run() { println(typeof(c).name) }

pub struct CmdMatch {
pub:
    name string = "match"
pub mut:
    x string
}

pub fn (c CmdMatch) read_args(args []string) {}
pub fn (c CmdMatch) run() { println(typeof(c).name) }

pub struct CmdRepl {
pub:
    name string = "repl"
pub mut:
    x string
}

pub fn (c CmdRepl) read_args(args []string) {}
pub fn (c CmdRepl) run() { println(typeof(c).name) }

pub struct CmdTest {
pub:
    name string = "test"
pub mut:
    x string
}

pub fn (c CmdTest) read_args(args []string) {}
pub fn (c CmdTest) run() { println(typeof(c).name) }

pub struct CmdExpand {
pub:
    name string = "expand"
pub mut:
    x string
}

pub fn (c CmdExpand) read_args(args []string) {}
pub fn (c CmdExpand) run() { println(typeof(c).name) }

pub struct CmdTrace {
pub:
    name string = "trace"
pub mut:
    x string
}

pub fn (c CmdTrace) read_args(args []string) {}
pub fn (c CmdTrace) run() { println(typeof(c).name) }

pub struct CmdReplxMatch {
pub:
    name string = "replxmatch"
pub mut:
    x string
}

pub fn (c CmdReplxMatch) read_args(args []string) {}
pub fn (c CmdReplxMatch) run() { println(typeof(c).name) }
