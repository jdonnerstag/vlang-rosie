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
	compile_1(mut c Compiler) ?
}


// PatternCompiler Generate byte code for a complete parser.Pattern, including predicates,
// multipliers, PatternElem, etc.
interface PatternCompiler {
	compile(mut c Compiler) ?
}

struct DefaultPatternCompiler {
pub:
	pat parser.Pattern
	predicate_be PredicateBE
	compile_1_be Compile_1
	compile_0_to_many_be Compile_0_to_many
}

fn (mut be DefaultPatternCompiler) compile(mut c Compiler) ? {
	pos := be.predicate_be.predicate_pre(mut c)?
	be.compile_inner(mut c)?
	be.predicate_be.predicate_post(mut c, pos)
}

fn (mut be DefaultPatternCompiler) compile_inner(mut c Compiler)? {
	pat := be.pat
	for _ in 0 .. pat.min {
		be.compile_1(mut c)?
	}

	if pat.max != -1 {
		if pat.max > pat.min {
			be.compile_0_to_n(mut c, pat.max - pat.min)?
		}
	} else {
		be.compile_0_to_many(mut c)?
	}
}

fn (mut be DefaultPatternCompiler) compile_1(mut c Compiler) ? {
	be.compile_1_be.compile_1(mut c) ?
}

fn (mut be DefaultPatternCompiler) compile_0_to_n(mut c Compiler, max int) ? {
	mut ar := []int{ cap: max }
	for _ in 0 .. max {
		ar << c.add_choice(0)
		be.compile_1(mut c) ?
		p2 := c.add_commit(0)
		c.update_addr(p2, c.code.len)
		// TODO This can be optimized with partial commit
	}

	for pc in ar { c.update_addr(pc, c.code.len) }
}

fn (mut be DefaultPatternCompiler) compile_0_to_many(mut c Compiler) ? {
	be.compile_0_to_many_be.compile_0_to_many(mut c) ?
}

// --------------------------------------------------------------------------------

// Compile_0_to_many Generate byte code that matches 0-to-many parser.PatternElem's.
// Without the predicate or multipliers associated with the pattern
interface Compile_0_to_many {
	compile_0_to_many(mut c Compiler) ?
}

struct DefaultCompile_0_to_many {
pub:
	pat parser.Pattern
	compile_1_be Compile_1
}

fn (mut be DefaultCompile_0_to_many) compile_0_to_many(mut c Compiler) ? {
	p1 := c.add_choice(0)
	be.compile_1_be.compile_1(mut c) ?
	c.add_commit(p1)
	// TODO This can be optimized with partial commit
	c.update_addr(p1, c.code.len)
}

// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------

// PredicateImpl Generate the byte code needed for the predicates
interface PredicateBE {
	predicate_pre(mut c Compiler) ? int
	predicate_post(mut c Compiler, behind int)
}

struct DefaultPredicateBE {
pub:
	pat parser.Pattern
}

fn (mut be DefaultPredicateBE) predicate_pre(mut c Compiler) ? int {
	mut pred_p1 := 0
	match be.pat.predicate {
		.na { }
		.negative_look_ahead {
			pred_p1 = c.add_choice(0)
		}
		.look_ahead {
			p1 := c.add_partial_commit(0)
			c.update_addr(p1, c.code.len)
		}
		.look_behind {
			behind := c.input_len(be.pat) or { 0 }
			if behind == 0 { return error("Look-behind is not supported for ${be.pat.elem.type_name()}: ${be.pat.repr()}") }
			pred_p1 = c.add_choice(0)
			c.add_behind(behind)
		}
		.negative_look_behind {
			behind := c.input_len(be.pat) or { 0 }
			if behind == 0 { return error("Negative-Look-behind is not supported for ${be.pat.elem.type_name()}: ${be.pat.repr()}") }
			pred_p1 = c.add_choice(0)
			c.add_behind(behind)
		}
	}

	return pred_p1
}

fn (mut be DefaultPredicateBE) predicate_post(mut c Compiler, behind int) {
	match be.pat.predicate {
		.na { }
		.negative_look_ahead {
			c.add_fail_twice()
			c.update_addr(behind, c.code.len)
		}
		.look_ahead {
			c.add_reset_pos()
		}
		.look_behind {
			p2 := c.add_commit(0)
			p3 := c.add_fail()
			c.update_addr(p2, c.code.len)
			c.update_addr(behind, p3)
		}
		.negative_look_behind {
			c.add_fail_twice()
			c.update_addr(behind, c.code.len)
		}
	}
}
