module cli

pub struct CmdList {}

pub fn (c CmdList) run(main MainArgs) ? { println(typeof(c).name) }

pub struct CmdGrep {}

pub fn (c CmdGrep) run(main MainArgs) ? { println(typeof(c).name) }

pub struct CmdMatch {}

pub fn (c CmdMatch) run(main MainArgs) ? { println(typeof(c).name) }

pub struct CmdRepl {}

pub fn (c CmdRepl) run(main MainArgs) ? { println(typeof(c).name) }

pub struct CmdExpand {}

pub fn (c CmdExpand) run(main MainArgs) ? { println(typeof(c).name) }

pub struct CmdTrace {}

pub fn (c CmdTrace) run(main MainArgs) ? { println(typeof(c).name) }

pub struct CmdReplxMatch {}

pub fn (c CmdReplxMatch) run(main MainArgs) ? { println(typeof(c).name) }
