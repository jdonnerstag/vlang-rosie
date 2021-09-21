module cli

import rosie.cli.core

pub struct CmdGrep {}

pub fn (c CmdGrep) run(main core.MainArgs) ? { println(typeof(c).name) }

pub struct CmdMatch {}

pub fn (c CmdMatch) run(main core.MainArgs) ? { println(typeof(c).name) }

pub struct CmdRepl {}

pub fn (c CmdRepl) run(main core.MainArgs) ? { println(typeof(c).name) }

pub struct CmdExpand {}

pub fn (c CmdExpand) run(main core.MainArgs) ? { println(typeof(c).name) }

pub struct CmdTrace {}

pub fn (c CmdTrace) run(main core.MainArgs) ? { println(typeof(c).name) }

pub struct CmdReplxMatch {}

pub fn (c CmdReplxMatch) run(main core.MainArgs) ? { println(typeof(c).name) }
