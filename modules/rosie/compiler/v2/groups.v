module v2

import rosie


struct GroupBE {
pub:
	pat rosie.Pattern
	elem rosie.GroupPattern
}

fn (cb GroupBE) compile(mut c Compiler) ? {
	mut x := DefaultPatternCompiler{
		pat: cb.pat,
		predicate_be: DefaultPredicateBE{ pat: cb.pat },
		compile_1_be: cb,
		compile_0_to_many_be: DefaultCompile_0_to_many{ pat: cb.pat, compile_1_be: cb }
	}

	x.compile(mut c) ?
}

fn (cb GroupBE) compile_1(mut c Compiler) ? {
	for e in cb.elem.ar {
		c.compile_elem(e, e)?
	}
}
