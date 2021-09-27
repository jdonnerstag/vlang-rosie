module compiler_backend_vm

import rosie.parser

// Components ...
// - a component for predicates
// - a compile_1 component
// - a compile_0_to_many component
// - a pattern compiler component
// These components must be separate; not in one struct;
// Each component must comply to an interface, so that I can replace default impl with a specialised one
// Then I probably need a component that plugs them together?

// Compile_1 Generate byte code that matches exactly one (1) parser.PatternElem.
// Without the predicate or multipliers associated with the pattern.
// There is no default implementation for this interface, as this is specific for every
// string, charset, group, etc.
interface Compile_1 {
	compile_1()
}


// PatternCompiler Generate byte code for a complete parser.Pattern, including predicates,
// multipliers, PatternElem, etc.
interface PatternCompiler {
	compile()
}

struct DefaultPatternCompiler {
pub:
	pat parser.Pattern
	predicate_be PredicateBE
	compile_1_be Compile_1
	compile_0_to_many_be Compile_0_to_many

pub mut:
	c Compiler
}

fn (mut be DefaultPatternCompiler) compile() ? {
	pos := be.predicate_be.predicate_pre()?
	be.compile_inner()
	be.predicate_be.predicate_post(pos)
}

fn (mut be DefaultPatternCompiler) compile_inner() {
	pat := be.pat
	for _ in 0 .. pat.min {
		be.compile_1()
	}

	if pat.max != -1 {
		if pat.max > pat.min {
			be.compile_0_to_n(pat.max - pat.min)
		}
	} else {
		be.compile_0_to_many()
	}
}

fn (mut be DefaultPatternCompiler) compile_1() {
	be.compile_1_be.compile_1()
}

fn (mut be DefaultPatternCompiler) compile_0_to_n(max int) {
	mut ar := []int{ cap: max }
	for _ in 0 .. max {
		ar << be.c.add_choice(0)
		be.compile_1()
		p2 := be.c.add_commit(0)
		be.c.update_addr(p2, be.c.code.len)
		// TODO This can be optimized with partial commit
	}

	for pc in ar { be.c.update_addr(pc, be.c.code.len) }
}

fn (mut be DefaultPatternCompiler) compile_0_to_many() {
	be.compile_0_to_many_be.compile_0_to_many()
}

// --------------------------------------------------------------------------------

// Compile_0_to_many Generate byte code that matches 0-to-many parser.PatternElem's.
// Without the predicate or multipliers associated with the pattern
interface Compile_0_to_many {
	compile_0_to_many()
}

struct DefaultCompile_0_to_many {
pub:
	pat parser.Pattern
	compile_1 Compile_1

pub mut:
	c Compiler
}

fn (mut be DefaultCompile_0_to_many) compile_0_to_many() {
	p1 := be.c.add_choice(0)
	be.compile_1.compile_1()
	be.c.add_commit(p1)
	// TODO This can be optimized with partial commit
	be.c.update_addr(p1, be.c.code.len)
}

// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------

// PredicateImpl Generate the byte code needed for the predicates
interface PredicateBE {
	predicate_pre() ? int
	predicate_post(behind int)
}

struct DefaultPredicateBE {
pub:
	pat parser.Pattern

pub mut:
	c Compiler
}

fn (mut be DefaultPredicateBE) predicate_pre() ? int {
	mut pred_p1 := 0
	match be.pat.predicate {
		.na { }
		.negative_look_ahead {
			pred_p1 = be.c.add_choice(0)
		}
		.look_ahead {
			p1 := be.c.add_partial_commit(0)
			be.c.update_addr(p1, be.c.code.len)
		}
		.look_behind {
			behind := be.pat.input_len() or { 0 }
			if behind == 0 { return error("Look-behind is not supportted for ${be.pat.elem.type_name()}: ${be.pat.repr()}") }
			pred_p1 = be.c.add_choice(0)
			be.c.add_behind(behind)
		}
		.negative_look_behind {
			behind := be.pat.input_len() or { 0 }
			if behind == 0 { return error("Negative-Look-behind is not supportted for ${be.pat.elem.type_name()}: ${be.pat.repr()}") }
			pred_p1 = be.c.add_choice(0)
			be.c.add_behind(behind)
		}
	}

	return pred_p1
}

fn (mut be DefaultPredicateBE) predicate_post(behind int) {
	match be.pat.predicate {
		.na { }
		.negative_look_ahead {
			be.c.add_fail_twice()
			be.c.update_addr(behind, be.c.code.len)
		}
		.look_ahead {
			be.c.add_reset_pos()
		}
		.look_behind {
			p2 := be.c.add_commit(0)
			p3 := be.c.add_fail()
			be.c.update_addr(p2, be.c.code.len)
			be.c.update_addr(behind, p3)
		}
		.negative_look_behind {
			be.c.add_fail_twice()
			be.c.update_addr(behind, be.c.code.len)
		}
	}
}
