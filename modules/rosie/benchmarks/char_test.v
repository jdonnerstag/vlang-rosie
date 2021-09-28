// TODO V bug 'benchmark' collides with V's internal compiler module
//module benchmark
module benchmarks

import time
import rosie.compiler_backend_vm as compiler
import rosie.runtime_v2 as rt

fn prepare_test(rpl string, name string, debug int) ? rt.Rplx {
    eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
    rplx := compiler.parse_and_compile(rpl: rpl, name: name, debug: debug, unit_test: false)?
    if debug > 0 { rplx.disassemble() }
	return rplx
}

fn run_benchmark(name string, rplx rt.Rplx, line string, count u64) ? {
    mut m := rt.new_match(rplx, 0)
	mut w := time.new_stopwatch()
	for i in 0 .. count {
	    m.vm_match(line)
		diff := m.stats.match_time.end - m.stats.match_time.start
	}
	w.stop()
	mut d := w.end - w.start
	eprintln("$name: diff: $count - ${d} - ${d / count} ns - $m.stats.instr_count - $m.stats.backtrack_len - $m.stats.capture_len")
}

fn test_simple_1() ? {
    rplx := prepare_test('"a"', "*", 0)?
	run_benchmark("test_simple_1:1", rplx, "", 1_000_000)?
	run_benchmark("test_simple_1:2", rplx, "a", 1_000_000)?
	run_benchmark("test_simple_1:3", rplx, "b", 1_000_000)?
}

fn test_simple_2() ? {
    rplx := prepare_test('"a"*', "*", 0)?
	run_benchmark("test_simple_2:1", rplx, "", 1_000_000)?
	run_benchmark("test_simple_2:2", rplx, "a", 1_000_000)?
	run_benchmark("test_simple_2:3", rplx, "aaaaa ", 1_000_000)?
	run_benchmark("test_simple_2:4", rplx, "b", 1_000_000)?
}

fn test_assert_fail() ? {
	assert false
}
