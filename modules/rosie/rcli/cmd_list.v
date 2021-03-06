module rcli

import cli
import rosie
import rosie.parser.stage_0 as parser

// Example output
//
// Name                     Cap? Type     Color           Source
// ------------------------ ---- -------- --------------- -------------------------
// $                             pattern  default;bold    builtin/prelude
// .                             pattern  default;bold    builtin/prelude
// ^                             pattern  default;bold    builtin/prelude
// backref                       macro                    builtin/prelude
// ci                            macro                    builtin/prelude
// error                         function                 builtin/prelude
// find                          macro                    builtin/prelude
// findall                       macro                    builtin/prelude
// keepto                        macro                    builtin/prelude
// message                       function                 builtin/prelude
// net                           package                  net.rpl
// ~                             pattern  default;bold    builtin/prelude
//
// 12/12 names shown

// List patterns, packages, and macros
pub fn cmd_list(cmd cli.Command) ? {
	init_rosie_with_cmd(cmd) ?

	mut count := 0
	mut count_filtered := 0

	// TODO update filter implementation
	filter := cmd.flags.get_string('filter')?.to_lower()
	eprintln("Filter: '$filter'")

	println('')
	println('Name                     Cap? Type     Color           Source')
	println('------------------------ ---- -------- --------------- -------------------------')

	// List all names registered with "main"
	p := parser.new_parser(debug: 0) ?
	mut pkg := p.package()
	for k, v in pkg.imports {
		count += 1
		str := '${k:24} ${' ':4} ${'package':8} ${' ':15} $v'
		if filter.len == 0 || str.to_lower().contains(filter) {
			count_filtered += 1
			println(str)
		}
	}

	for {
		for b in pkg.bindings {
			count += 1
			ptype := match b.pattern.elem {
				rosie.LiteralPattern { 'pattern' }
				rosie.CharsetPattern { 'charset' }
				rosie.GroupPattern { 'pattern' }
				rosie.DisjunctionPattern { 'pattern' }
				rosie.NamePattern { 'name' }
				rosie.EofPattern { 'pattern' }
				rosie.MacroPattern { 'macro' }
				rosie.FindPattern { 'macro' }
				rosie.NonePattern { '' }
			}

			str := '${b.name:-24} ${' ':-4} ${ptype:-8} ${' ':-15} $b.package'
			if filter.len == 0 || str.to_lower().contains(filter) {
				count_filtered += 1
				println(str)
			}
		}

		if pkg.has_parent() == false {
			break
		}

		pkg = pkg.parent
	}

	println('')
	println('$count_filtered/$count names shown')
	println('')
}
