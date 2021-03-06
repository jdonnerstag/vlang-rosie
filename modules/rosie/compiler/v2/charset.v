module v2

import rosie

enum CharsetBEOptimizations {
	standard
	bit_7
	digits
}

struct CharsetBE {
mut:
	optimization CharsetBEOptimizations = .standard
	count int
pub:
	pat rosie.Pattern
	cs rosie.Charset
}

fn (mut cb CharsetBE) compile(mut c Compiler) ? {
	if cb.pat.min == 0 && cb.pat.max == 1 {
		cb.compile_optional_charset(mut c)
		return
	} else if cb.cs.is_equal(rosie.known_charsets["ascii"]) {
		cb.optimization = .bit_7
	} else if cb.cs.is_equal(rosie.known_charsets["digit"]) {
		cb.optimization = .digits
	}

	mut x := DefaultPatternCompiler{
		pat: cb.pat,
		predicate_be: DefaultPredicateBE{ pat: cb.pat }
		compile_1_be: cb,
		compile_0_to_many_be: cb
	}

	x.compile(mut c) ?
}

fn (cb CharsetBE) compile_1(mut c Compiler) ? {
	if cb.optimization == .bit_7 {
		c.add_bit_7()
	} else if cb.optimization == .digits {
		c.add_digit()
	} else {
		c.add_set(cb.cs)
	}
}

fn (cb CharsetBE) compile_0_to_many(mut c Compiler) ? {
	c.add_span(cb.cs)
}

fn (cb CharsetBE) chars_as_int(cs rosie.Charset) (int, int) {
	mut rtn := 0
	mut cnt := 0
	for i in 0 .. rosie.uchar_max {
		if cs.contains(byte(i)) {
			cnt += 1
			if cnt > 4 { break }

			rtn = int((u32(rtn) << 8) | (i & 0xff))
		}
	}
	return cnt, rtn
}

fn (cb CharsetBE) compile_optional_charset(mut c Compiler) {
	p1 := c.add_test_set(cb.cs, 0)
	c.add_any()
	c.update_addr(p1, c.rplx.code.len)
}
