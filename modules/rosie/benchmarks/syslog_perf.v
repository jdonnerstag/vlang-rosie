// TODO V bug 'benchmark' collides with V's internal compiler module
// module benchmark
module main

// TODO Not sure of V executes tests (or test files) in parallel. That may not be what
// we want for performance test. May be we need to revert these tests to a normal executable.
import os
import time
import rosie.compiler_backend_vm as compiler
import rosie.runtime_v2 as rt
// import rosie.cli.core

const (
	data_dir   = os.dir(@FILE) + '/test/data'
	syslog_rpl = '$data_dir/syslog.rpl'
	log_dir    = os.dir(@FILE) + '/test/perf'
)

pub const vmod_version = get_version()

fn get_version() string {
	mut v := '0.0.0'
	vmod := @VMOD_FILE
	if vmod.len > 0 {
		if vmod.contains('version:') {
			v = vmod.all_after('version:').all_before('\n').replace("'", '').replace('"',
				'').trim(' ')
		}
	}
	return v
}

fn prepare_test(rpl string, name string, debug int) ?rt.Rplx {
	eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
	rplx := compiler.parse_and_compile(rpl: rpl, name: name, debug: debug, unit_test: false) ? //, captures: ["*"])?
	if debug > 0 {
		rplx.disassemble()
	}
	return rplx
}

fn run_benchmark(name string, rplx rt.Rplx, data string, count u64, logfile string) ? {
	mut m := rt.new_match(rplx, 0)
	m.skip_to_newline = true

	mut w := time.new_stopwatch()
	for _ in 0 .. count {
		m.vm_match(data)
		for m.pos < m.input.len {
			m.captures.clear()
			m.vm(0, m.pos)
		}
	}

	w.stop()
	d := w.end - w.start
	instr_per_ms := 1_000_000 * u64(m.stats.instr_count) * u64(count) / d
	char_per_ms := u64(data.len) * count * 1_000_000 / d

	diff_str := rt.str_duration(d)
	diff_per_iter_str := rt.str_duration(d / count)
	instr_count_str := rt.thousand_grouping(u64(m.stats.instr_count), `,`)
	instr_per_ms_str := rt.thousand_grouping(instr_per_ms, `,`)
	bt_len_str := '$m.stats.backtrack_len'
	cap_len_str := '$m.stats.capture_len'
	char_per_ms_str := rt.thousand_grouping(char_per_ms, `,`)
	eprintln('$name: iterations: $count - $diff_str / $diff_per_iter_str - instr: $instr_count_str / $instr_per_ms_str ipms - bt.len: $bt_len_str - cap.len: $cap_len_str - chars per ms: $char_per_ms_str')

	$if debug {
		rt.print_histogram(m.stats)
	}

	if logfile.len > 0 {
		version := vmod_version

		res := os.execute('git rev-parse --short HEAD')
		git_rev := if res.exit_code == 0 { res.output } else { '<unknown>' }

		mut fd := os.open_append(logfile) ?
		defer {
			fd.close()
		}
		fd.write_string("{dt: '$time.now().format_ss()'") ?
		fd.write_string(', iterations: $count, duration: $d, dur_per_iter: ${d / count}') ?
		fd.write_string(', instructions: $m.stats.instr_count, instr_per_ms: $instr_per_ms') ?
		fd.write_string(', bt_len: $m.stats.backtrack_len, cap_len: $m.stats.capture_len') ?
		fd.write_string(", version: '$version', gitrev: '$git_rev'") ?
		fd.writeln('}') ?
	}
}

fn main() {
	mut rplx := prepare_test('import $syslog_rpl as sl; sl.syslog', '*', 0) ?

	mut data := ''
	run_benchmark('test_syslog_1:1', rplx, data, 1_000, '') ?
/* */
	data = '2015-08-23T03:36:25-05:00 10.108.69.93 sshd[16537]: Did not receive identification string from 208.43.117.11'
	run_benchmark('test_syslog_1:2', rplx, data, 1_000, '') ?

	data = os.read_file('$data_dir/log10.txt') ?
	run_benchmark('test_syslog_1:3', rplx, data, 1_000, '') ?

	data = os.read_file('$data_dir/log100.txt') ?
	run_benchmark('test_syslog_1:4', rplx, data, 100, '') ?

	data = os.read_file('$data_dir/log163840.txt') ?
	run_benchmark('test_syslog_1:5', rplx, data, 1, '$log_dir/syslog_16k.perf.log') ?

	rplx = prepare_test('import $syslog_rpl as sl; sl.anything', '*', 0) ?
	// data = os.read_file("${data_dir}/log163840.txt")?
	data = '2015-08-23T03:36:25-05:00 10.108.69.93 sshd[16537]: Did not receive identification string from 208.43.117.11'
	// mut m := rt.new_match(rplx, 0)
	// m.vm_match(data)
	// m.print_captures(false)
	run_benchmark('test_syslog_1:2', rplx, data, 1_000, '') ?
/* */
}
