module rpl


import os
import rosie
import rosie.runtime_v2 as rt
import rosie.compiler_vm_backend as compiler

struct Parser {
pub:
	rplx_preparse rt.Rplx
	rplx_stmts rt.Rplx

	debug int
	import_path []string

pub mut:
	package_cache &PackageCache
	package string		// The current variable context
	grammar string		// Set if anywhere between 'grammar' .. 'end'

	parents []Pattern
	recursions []string		// Detect recursions

	m rt.Match
}

pub fn init_libpath() ? []string {
	rosie := rosie.init_rosie()?
	return rosie.libpath
}

[params]	// TODO A little sad that V-lang requires this hint, rather then the language being properly designed
pub struct ParserOptions {
	package string = "main"
	debug int
	package_cache &PackageCache = &PackageCache{}
}

pub fn new_parser(args ParserOptions) ?Parser {
	rpl := os.read_file('./rpl/rosie/rpl_1_3.rpl')?
	rplx_preparse := compiler.parse_and_compile(rpl: rpl, name: "preparse")?
	rplx_stmts := compiler.parse_and_compile(rpl: rpl, name: "rpl_statements")?

	mut parser := Parser {
		rplx_preparse: rplx_preparse
		rplx_stmts: rplx_stmts
		debug: args.debug
		package_cache: args.package_cache
		package: args.package
		import_path: init_libpath()?
	}

	parser.package_cache.add_package(name: args.package, fpath: args.package)?

	// Add builtin package, if not already present
	parser.package_cache.add_builtin()

	return parser
}

pub fn (mut p Parser) find_symbol(name string) ? int {
	return p.m.rplx.symbols.find(name)
}

pub fn (mut p Parser) parse(rpl string, debug int) ? {
	data := os.read_file(rpl) or { rpl }

	mut m := rt.new_match(p.rplx_preparse, 0)
	start_pos := if m.vm_match(data) { m.pos } else { 0 }

	p.m = rt.new_match(p.rplx_stmts, 0)
	p.m.input = data
	if p.m.vm(0, start_pos) == false {
		return error('RPL parser: some error occurred (improve)')
	}

	nl_idx := p.find_symbol("rpl_1_3.newline")?
	comment_idx := p.find_symbol("rpl_1_3.comment")?
	pkg_decl_idx := p.find_symbol("rpl_1_3.package_decl")?
	import_idx := p.find_symbol("rpl_1_3.import_decl")?
	language_idx := p.find_symbol("rpl_1_3.language_decl")?
	gr_binding_idx := p.find_symbol("rpl_1_3.grammar-2.binding")?

	// See https://github.com/vlang/v/issues/12411 for a V-bug on iterators
	mut iter := p.m.captures.my_filter()
	for {
		cap := iter.next() or { break }
		if cap.level != 1 { continue }

		//eprintln("pos: $iter.idx, ${p.m.captures.data}, ${p.m.capture_str(cap)}")
		// package_decl / import_decl / language_decl / binding / exp
		match cap.idx {
			pkg_decl_idx {
				p.parse_package_decl(iter.last(), cap)?
			}
			import_idx {
				p.parse_import_decl(iter.last(), cap)?
			}
			language_idx {
				p.parse_language_decl(iter.last(), cap)?
			}
			gr_binding_idx {
				p.parse_binding(iter.last(), cap)?
			}
			nl_idx, comment_idx {
				// skip
			}
			else {
				return error("RPL parser: missing implementation for '${p.m.capture_str(cap)}'")
			}
		}
	}
}

pub fn (mut p Parser) parse_package_decl(pos int, cap rt.Capture) ? {
	eprintln("Entering: ${@FN}")
	//p.m.print_capture_level(pos)

	packagename_idx := p.find_symbol("rpl_1_3.packagename")?
	child_idx := p.m.child_capture(pos, pos, packagename_idx)?
	name := p.m.get_capture_input(p.m.captures[child_idx])

	eprintln("package: '$name'")
	p.package().name = name
	p.package = name
}

pub fn (mut p Parser) parse_import_decl(pos int, cap rt.Capture) ? {
	eprintln("Entering: ${@FN}")
	p.m.print_capture_level(pos)
	return error("Not yet implemented: ${@FN}()")
}

pub fn (mut p Parser) parse_language_decl(pos int, cap rt.Capture) ? {
	eprintln("Entering: ${@FN}")
	p.m.print_capture_level(pos)
	return error("Not yet implemented: ${@FN}()")
}

pub fn (mut p Parser) parse_binding(pos int, cap rt.Capture) ? {
	//eprintln("Entering: ${@FN}")
	//p.m.print_capture_level(pos)

	grammar_idx := p.find_symbol("rpl_1_3.grammar-2.grammar_block")?
	let_idx := p.find_symbol("rpl_1_3.grammar-2.let_block")?
	simple_idx := p.find_symbol("rpl_1_3.grammar-2.simple")?

	child_pos := p.m.capture_next_child_match(pos + 1, -1)?
	cap_idx := p.m.captures[child_pos].idx

	match cap_idx {
		grammar_idx {
			p.parse_grammar(child_pos, cap)?
		}
		let_idx {
			p.parse_let(child_pos, cap)?
		}
		simple_idx {
			p.parse_simple(child_pos, cap)?
		}
		else {
			return error("RPL parser: unexpected capture idx: $cap_idx at capture index $child_pos within ${@FN}()")
		}
	}
}

pub fn (mut p Parser) parse_grammar(pos int, cap rt.Capture) ? {
	p.m.print_capture_level(pos)
	return error("Not yet implemented: ${@FN}()")
}

pub fn (mut p Parser) parse_let(pos int, cap rt.Capture) ? {
	p.m.print_capture_level(pos)
	return error("Not yet implemented: ${@FN}()")
}

pub fn (mut p Parser) parse_simple(pos int, cap rt.Capture) ? {
	//eprintln("Entering: ${@FN}")
	//p.m.print_capture_level(pos)

	// simple = {local_? atmos alias_? atmos identifier atmos "=" atmos exp}

	local_idx := p.find_symbol("rpl_1_3.grammar-2.local_")?
	alias_idx := p.find_symbol("rpl_1_3.grammar-2.alias_")?
	identifier_idx := p.find_symbol("rpl_1_3.identifier")?
	exp_idx := p.find_symbol("rpl_1_3.grammar-2.exp")?

	level := p.m.captures[pos].level
	mut child_pos := p.m.capture_next_child_match(pos + 1, level)?
	mut cap_idx := p.m.captures[child_pos].idx

	mut blocal := false
	if cap_idx == local_idx {
		blocal = true
		child_pos = p.m.capture_next_child_match(child_pos + 1, level)?
		cap_idx = p.m.captures[child_pos].idx
	}

	mut balias := false
	if cap_idx == alias_idx {
		balias = true
		child_pos = p.m.capture_next_child_match(child_pos + 1, level)?
		cap_idx = p.m.captures[child_pos].idx
	}

	if cap_idx != identifier_idx {
		return error("RPL: expected to find a 'rpl_1_3.grammar-2.identifier': ${p.m.capture_str(cap)}")
	}

	identifier := p.m.get_capture_input(p.m.captures[child_pos])
	eprintln("Binding: identifier = '$identifier'")

	child_pos = p.m.capture_next_sibling_match(child_pos)?
	p.parse_exp(child_pos, cap)?
}

pub fn (mut p Parser) parse_exp(pos int, cap rt.Capture) ? {
	//eprintln("Entering: ${@FN}")
	//p.m.print_capture_level(pos)

   	// exp = infix
	// alias infix = {atmos {predicate / term} {atmos operator? infix}* }

	predicate_idx := p.find_symbol("rpl_1_3.grammar-2.predicate")?
	term_idx := p.find_symbol("rpl_1_3.grammar-2.term")?
	operator_idx := p.find_symbol("rpl_1_3.operator")?

	level := p.m.captures[pos].level
	mut child_pos := p.m.capture_next_child_match(pos + 1, level) or {
		p.m.print_capture_level(pos)
		return err
	}

	mut cap_idx := p.m.captures[child_pos].idx

	match cap_idx {
		predicate_idx {
			p.parse_predicate(child_pos, cap)?
		}
		term_idx {
			p.parse_term(child_pos, cap)?
		}
		else {
			return error("RPL parser: unexpected capture idx: $cap_idx at capture index $child_pos within ${@FN}()")
		}
	}

	child_pos = p.m.capture_next_child_match(child_pos + 1, level) or {
		p.m.print_capture_level(child_pos)
		return err
	}

	cap_idx = p.m.captures[child_pos].idx
	if cap_idx == operator_idx {
		p.parse_operator(child_pos, cap) or {
			p.m.print_capture_level(child_pos)
			return err
		}

		child_pos = p.m.capture_next_sibling_match(child_pos)?
	}

	p.parse_exp(child_pos, cap) or {
		p.m.print_capture_level(child_pos)
		return err
	}
}

pub fn (mut p Parser) parse_predicate(pos int, cap rt.Capture) ? {
	//eprintln("Entering: ${@FN}")
	p.m.print_capture_level(pos)

	return error("Not yet implemented: ${@FN}()")
}

pub fn (mut p Parser) parse_term(pos int, cap rt.Capture) ? {
	eprintln("Entering: ${@FN}")
	p.m.print_capture_level(pos)

   	// term = {base_term quantifier?}

	range_idx := p.find_symbol("rpl_1_3.range")?
	quantifier_idx := p.find_symbol("rpl_1_3.quantifier")?
	raw_idx := p.find_symbol("rpl_1_3.grammar-2.raw")?
	cooked_idx := p.find_symbol("rpl_1_3.grammar-2.cooked")?
	literal_idx := p.find_symbol("rpl_1_3.literal")?
	identifier_idx := p.find_symbol("rpl_1_3.identifier")?

	level := p.m.captures[pos].level
	mut child_pos := p.m.capture_next_child_match(pos + 1, level) or {
		p.m.print_capture_level(pos)
		return err
	}

	mut cap_idx := p.m.captures[child_pos].idx

	match cap_idx {
		range_idx {
			p.parse_range(child_pos, cap)?
		}
		raw_idx {
			p.parse_raw(child_pos, cap)?
		}
		cooked_idx {
			p.parse_cooked(child_pos, cap)?
		}
		literal_idx {
			p.parse_literal(child_pos, cap)?
		}
		identifier_idx {
			p.parse_identifier(child_pos, cap)?
		}
		else {
			p.m.print_capture_level(pos)
			return error("${@FN}(): Unexpected capture. pos: $child_pos")
		}
	}

	if xchild_pos := p.m.capture_next_child_match(child_pos + 1, level) {
		cap_idx = p.m.captures[xchild_pos].idx
		if cap_idx != quantifier_idx {
			p.m.print_capture_level(pos)
			return error("${@FN}(): Expected 'quantifier' - pos: $child_pos")
		}
		p.parse_quantifier(xchild_pos, cap)?
	}
}

pub fn (mut p Parser) parse_operator(pos int, cap rt.Capture) ? {
	//eprintln("Entering: ${@FN}")
	//p.m.print_capture_level(pos)

	operator := p.m.get_capture_input(p.m.captures[pos])
	eprintln("Operator: $operator")
}

pub fn (mut p Parser) parse_range(pos int, cap rt.Capture) ? {
	//eprintln("Entering: ${@FN}")
	//p.m.print_capture_level(pos)

	range_first_idx := p.find_symbol("rpl_1_3.range_first")?
	range_last_idx := p.find_symbol("rpl_1_3.range_last")?

	level := p.m.captures[pos].level
	first_pos := p.m.child_capture(pos, pos, range_first_idx)?
	last_pos := p.m.child_capture(pos, first_pos, range_last_idx)?

	first := p.m.get_capture_input(p.m.captures[first_pos])
	last := p.m.get_capture_input(p.m.captures[last_pos])

	eprintln("Range: '$first' - '$last'")
}

pub fn (mut p Parser) parse_quantifier(pos int, cap rt.Capture) ? {
	//eprintln("Entering: ${@FN}")
	//p.m.print_capture_level(pos)

	repetition_idx := p.find_symbol("rpl_1_3.repetition")?
	low_idx := p.find_symbol("rpl_1_3.low")?
	high_idx := p.find_symbol("rpl_1_3.high")?
	question_idx := p.find_symbol("rpl_1_3.question")?

	level := p.m.captures[pos].level
	mut child_pos := p.m.capture_next_child_match(pos + 1, level)?
	mut cap_idx := p.m.captures[child_pos].idx

	mut low := "0"
	mut high := "0"
	if cap_idx == repetition_idx {
		if low_pos := p.m.child_capture(pos, pos, low_idx) {
			low = p.m.get_capture_input(p.m.captures[low_pos])
		}

		if high_pos := p.m.child_capture(pos, pos, high_idx) {
			high = p.m.get_capture_input(p.m.captures[high_pos])
		}
	} else if cap_idx == question_idx {
		low = "0"
		high = "1"
	} else {
		p.m.print_capture_level(pos)
		return error("${@FN}(): Invalid capture: $cap_idx; pos: $child_pos")
	}

	eprintln("Quantifier: Repetition: {$low,$high}")
}

pub fn (mut p Parser) parse_raw(pos int, cap rt.Capture) ? {
	//eprintln("Entering: ${@FN}")
	//p.m.print_capture_level(pos)

	exp_idx := p.find_symbol("rpl_1_3.grammar-2.exp")?

	level := p.m.captures[pos].level
	mut child_pos := p.m.capture_next_child_match(pos + 1, level)?
	mut cap_idx := p.m.captures[child_pos].idx

	if cap_idx != exp_idx {
		p.m.print_capture_level(pos)
		return error("${@FN}(): expected 'exp' capture. pos: $pos")
	}

	p.parse_exp(child_pos, cap)?
}

pub fn (mut p Parser) parse_literal(pos int, cap rt.Capture) ? {
	//eprintln("Entering: ${@FN}")
	//p.m.print_capture_level(pos)

	value := p.m.get_capture_input(p.m.captures[pos])
	eprintln("Literal: $value")
}

pub fn (mut p Parser) parse_identifier(pos int, cap rt.Capture) ? {
	//eprintln("Entering: ${@FN}")
	//p.m.print_capture_level(pos)

	identifier := p.m.get_capture_input(p.m.captures[pos])
	eprintln("Identifier: $identifier")
}

// TODO Same as parse_raw
pub fn (mut p Parser) parse_cooked(pos int, cap rt.Capture) ? {
	//eprintln("Entering: ${@FN}")
	//p.m.print_capture_level(pos)

	exp_idx := p.find_symbol("rpl_1_3.grammar-2.exp")?

	level := p.m.captures[pos].level
	mut child_pos := p.m.capture_next_child_match(pos + 1, level)?
	mut cap_idx := p.m.captures[child_pos].idx

	if cap_idx != exp_idx {
		p.m.print_capture_level(pos)
		return error("${@FN}(): expected 'exp' capture. pos: $pos")
	}

	p.parse_exp(child_pos, cap)?
}
