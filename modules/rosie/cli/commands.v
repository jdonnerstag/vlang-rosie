module cli

import rosie.cli.core

pub struct CmdGrep {}

pub fn (c CmdGrep) run(main core.MainArgs) ? { println(typeof(c).name) }
pub fn (c CmdGrep) print_help() { println("help") }

pub struct CmdMatch {}

pub fn (c CmdMatch) run(main core.MainArgs) ? { println(typeof(c).name) }
pub fn (c CmdMatch) print_help() { println("help") }

pub struct CmdRepl {}

pub fn (c CmdRepl) run(main core.MainArgs) ? { println(typeof(c).name) }
pub fn (c CmdRepl) print_help() { println("help") }

pub struct CmdExpand {}

pub fn (c CmdExpand) run(main core.MainArgs) ? { println(typeof(c).name) }
pub fn (c CmdExpand) print_help() { println("help") }

pub struct CmdTrace {}

pub fn (c CmdTrace) run(main core.MainArgs) ? { println(typeof(c).name) }
pub fn (c CmdTrace) print_help() { println("help") }

pub struct CmdReplxMatch {}

pub fn (c CmdReplxMatch) run(main core.MainArgs) ? { println(typeof(c).name) }
pub fn (c CmdReplxMatch) print_help() { println("help") }
