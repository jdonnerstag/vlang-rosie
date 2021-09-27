module compiler_backend_vm

import rosie.parser

// Components ...
// - a component for predicates
// - a compile_1 component
// - a compile_0_to_many component
// - a pattern compiler component
// These components must be separate; not in one struct;
// Each component must comply to an interface, so that each one individually
// can be replaced separately.

// Compile_1 Interface for a component that generates the byte code that matches
// the pattern (without predicate and multipliers) exactly ones (1).
// There is no default implementation for this interface, as this is specific for every
// string, charset, group, etc.
interface Compile_1 {
	compile_1(mut c Compiler) ?
}

// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------

// PatternCompiler Interface for a (wrapper) component that stitches several other
// components together, to generate all the byte code needed for a pattern, including
// predicates and multipliers.
interface PatternCompiler {
	compile(mut c Compiler) ?
}

// DefaultPatternCompiler Default implementation of a "wrapper" component
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
	if max > 0 {
		p1 := c.add_choice(0)
		for i in 0 .. max {
			be.compile_1(mut c) ?
			p2 := if (i + 1) < max {
				c.add_partial_commit(0)
			} else {
				c.add_commit(0)
			}
			c.update_addr(p2, c.code.len)
		}

		c.update_addr(p1, c.code.len)
	}
}

fn (mut be DefaultPatternCompiler) compile_0_to_many(mut c Compiler) ? {
	be.compile_0_to_many_be.compile_0_to_many(mut c) ?
}

// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------

// Compile_0_to_many Interface for a component that generates the byte code needed
// for 0-to-many matches of a pattern, e.g. "a"*
interface Compile_0_to_many {
	compile_0_to_many(mut c Compiler) ?
}

// DefaultCompile_0_to_many Default implementation of a "0-to-many" component
struct DefaultCompile_0_to_many {
pub:
	pat parser.Pattern
	compile_1_be Compile_1
}

fn (mut be DefaultCompile_0_to_many) compile_0_to_many(mut c Compiler) ? {
	p1 := c.add_choice(0)
	p2 := c.code.len
	be.compile_1_be.compile_1(mut c) ?
	c.add_partial_commit(p2)
	c.update_addr(p1, c.code.len)
}

// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------

// PredicateImpl Interface for a component that generates the byte code needed
// for the predicates.
interface PredicateBE {
	predicate_pre(mut c Compiler) ? int
	predicate_post(mut c Compiler, behind int)
}

// DefaultPredicateBE Default implementation of a "predicate" component
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
			pred_p1 = c.add_choice(0)
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
			p2 := c.add_back_commit(0)
			p3 := c.add_fail()
			c.update_addr(p2, c.code.len)
			c.update_addr(behind, p3)
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
