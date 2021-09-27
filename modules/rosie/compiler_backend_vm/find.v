module compiler_backend_vm

import rosie.parser


struct FindBE {
pub:
	pat parser.Pattern
	elem parser.FindPattern
}


fn (cb FindBE) compile(mut c Compiler) ? {
	mut x := DefaultPatternCompiler{
		pat: cb.pat,
		predicate_be: DefaultPredicateBE{ pat: cb.pat },
		compile_1_be: cb,
		compile_0_to_many_be: DefaultCompile_0_to_many{ pat: cb.pat, compile_1_be: cb }
	}

	x.compile(mut c) ?
}

fn (cb FindBE) compile_1(mut c Compiler) ? {
	// TODO Find can be (significantly) optimized for specific pattern.
	// If it is not a choice (but starts with a char charset), then use a new byte code instruction: "until"
	// The keepto and findall macros are quite simiar.
	find_pat := cb.elem
	a := parser.Pattern{ predicate: .negative_look_ahead, elem: parser.GroupPattern{ ar: [find_pat.pat] } }
	b := parser.Pattern{ elem: parser.NamePattern{ name: "." } }
	search_pat := parser.Pattern{ min: 0, max: -1, elem: parser.GroupPattern{ ar: [a, b] } }

	if find_pat.keepto == false {
		c.compile_elem(search_pat, search_pat)?
	} else {
		c.add_open_capture("find:<search>")
		c.compile_elem(search_pat, search_pat)?
		c.add_close_capture()
	}

	x := parser.Pattern{ elem: parser.GroupPattern{ ar: [find_pat.pat] } }
	c.add_open_capture("find:*")
	c.compile_elem(x, x)?
	c.add_close_capture()
}
