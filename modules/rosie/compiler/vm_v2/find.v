module vm_v2

import rosie


struct FindBE {
pub:
	pat rosie.Pattern
	elem rosie.FindPattern
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
	// Optimizations: Find can be (significantly) optimized for specific pattern.
	// If it is not a choice (but starts with a char or charset), then use a new
	// byte code instruction: "until"
	// Same for keepto and findall macros.
	find_pat := cb.elem
	if find_pat.pat.elem is rosie.LiteralPattern {
		cb.find_literal(mut c, find_pat.keepto, find_pat.pat, find_pat.pat.elem.text[0])?
		return
	} else if find_pat.pat.elem is rosie.CharsetPattern {
		cb.find_charset(mut c, find_pat.keepto, find_pat.pat, find_pat.pat.elem.cs)?
		return
	}

	a := rosie.Pattern{ predicate: .negative_look_ahead, elem: rosie.GroupPattern{ ar: [find_pat.pat] } }
	b := rosie.Pattern{ elem: rosie.NamePattern{ name: "." } }
	search_pat := rosie.Pattern{ min: 0, max: -1, elem: rosie.GroupPattern{ ar: [a, b] } }

	if find_pat.keepto == false {
		c.compile_elem(search_pat, search_pat)?
	} else {
		c.add_open_capture("find:<search>")
		c.compile_elem(search_pat, search_pat)?
		c.add_close_capture()
	}

	x := rosie.Pattern{ elem: rosie.GroupPattern{ ar: [find_pat.pat] } }
	c.add_open_capture("find:*")
	c.compile_elem(x, x)?
	c.add_close_capture()
}

fn (cb FindBE) find_literal(mut c Compiler, keepto bool, pat rosie.Pattern, ch byte) ? {
	mut p1 := 0
	if keepto == false {
		p1 = c.add_until_char(ch, true)
	} else {
		c.add_open_capture("find:<search>")
		p1 = c.add_until_char(ch, true)
		c.add_close_capture()
	}

	p2 := c.add_choice(0)
	c.add_open_capture("find:*")
	c.compile_elem(pat, pat)?		// TODO Do we still need both parameters?
	c.add_close_capture()
	p3 := c.add_commit(0)
	p4 := c.add_any()
	c.add_jmp(p1)
	c.update_addr(p2, p4)
	c.update_addr(p3, c.rplx.code.len)
}

fn (cb FindBE) find_charset(mut c Compiler, keepto bool, pat rosie.Pattern, cs rosie.Charset) ? {
	if keepto == false {
		c.add_until_set(cs, true)
	} else {
		c.add_open_capture("find:<search>")
		c.add_until_set(cs, true)
		c.add_close_capture()
	}

	c.add_open_capture("find:*")
	c.compile_elem(pat, pat)?		// TODO Do we still need both parameters?
	c.add_close_capture()
}
