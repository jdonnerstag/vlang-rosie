module compiler_backend_vm

import rosie.runtime_v2 as rt
import rosie.parser

enum CharsetBEOptimizations {
	standard
	one_char
	bit_7
	digits
}

struct CharsetBE {
mut:
	optimization CharsetBEOptimizations = .standard
	count int
pub:
	pat parser.Pattern
	cs rt.Charset
}

fn (mut cb CharsetBE) compile(mut c Compiler) ? {
	if cb.cs.is_equal(rt.known_charsets["ascii"]) {
		cb.optimization = .bit_7
	} else if cb.cs.is_equal(rt.known_charsets["digit"]) {
		cb.optimization = .digits
	} else {
		count, _ := cb.cs.count()
		if count == 1 {
			cb.optimization = .one_char
		}
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
		c.add_set_from_to(48, 57)
	} else if cb.optimization == .one_char {
		_, bytes := cb.chars_as_int(cb.cs)
		ch := byte(bytes & 0xff)
		c.add_char(ch)
	} else {
		c.add_set(cb.cs)
	}
}

fn (cb CharsetBE) compile_0_to_many(mut c Compiler) ? {
	c.add_span(cb.cs)
}

fn (cb CharsetBE) chars_as_int(cs rt.Charset) (int, int) {
	mut rtn := 0
	mut cnt := 0
	for i in 0 .. C.UCHAR_MAX {
		if cs.cmp_char(byte(i)) {
			cnt += 1
			if cnt > 4 { break }

			rtn = (rtn << 8) | (i & 0xff)
		}
	}
	return cnt, rtn
}
