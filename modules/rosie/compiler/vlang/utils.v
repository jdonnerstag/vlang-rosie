module vlang

//import rosie.parser.stage_0 as parser
import rosie.parser.rpl_1_3 as parser
import rosie.expander

pub struct ParseAndCompileOptions {
	rpl string
	name string
	debug int
	unit_test bool
	captures []string
}

// TODO remove later on

pub fn parse_and_compile(args ParseAndCompileOptions) ? string {
	if args.debug > 0 {
		eprintln("Parse RPL input")
	}
	mut p := parser.new_parser(debug: args.debug)?
	p.parse(data: args.rpl) or {
		return error("Stage 'parse': $err.msg")
	}
	if args.debug > 1 {
		eprintln(p.binding(args.name)?.repr())
	}

	if args.debug > 0 {
		eprintln("Expand parsed input for binding: '$args.name'")
	}

	mut e := expander.new_expander(main: p.main, debug: p.debug, unit_test: false)
	e.expand(args.name) or {
		return error("Compiler failure in expand(): $err.msg")
	}

	if args.debug > 1 {
		eprintln(p.binding(args.name)?.repr())
	}

	mut c := new_compiler(p.main, unit_test: args.unit_test, debug: args.debug)?
	c.user_captures = args.captures
	c.compile(args.name) or {
		return error("Stage 'compile': $err.msg")
	}

	//p.main.print_bindings()
	return c.result
}
