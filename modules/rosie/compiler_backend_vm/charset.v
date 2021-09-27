module compiler_backend_vm

import rosie.runtime_v2 as rt
import rosie.parser


struct CharsetBE {
pub:
	pat parser.Pattern
	cs rt.Charset
}

fn (cb CharsetBE) compile(mut c Compiler) ? {
	mut x := DefaultPatternCompiler{
		pat: cb.pat,
		predicate_be: DefaultPredicateBE{ pat: cb.pat }
		compile_1_be: cb,
		compile_0_to_many_be: cb
	}

	x.compile(mut c) ?
}

fn (mut cb CharsetBE) compile_1(mut c Compiler) {
	c.add_set(cb.cs)
}

fn (mut cb CharsetBE) compile_0_to_many(mut c Compiler) {
	c.add_span(cb.cs)
}
