module v2

import time

struct Stats {
pub mut:
	match_time time.StopWatch
	instr_count int				// number of vm instructions executed
	backtrack_len int			// max len of backtrack stack used by vm
	capture_len int    			// max len of capture list used by vm

	backtrack_push_count int	// How often btstack.push() was called
	capture_push_count int    	// How often captures.push() was called.

	// TODO make this dependent on -profiler argument. Size must be larger then the number of VM instructions
	histogram [256]HistogramEntry
}

struct HistogramEntry {
pub mut:
	count int
	timer time.StopWatch = time.new_stopwatch(auto_start: false)
}

fn new_stats() Stats {
	return Stats{ match_time: time.new_stopwatch() }
}


struct HistoData {
pub:
	opcode Opcode
	count int
	elapsed u64
	avg_elapsed i64
}

fn prepare_histogram(s Stats) []HistoData {
	mut hist := []HistoData{}
	for i, e in s.histogram {
		if e.count > 0 {
			hist << HistoData {
				opcode: Opcode(i),
				count: e.count,
				elapsed: e.timer.elapsed(),
				avg_elapsed: e.timer.elapsed() / time.Duration(e.count),
			}
		}
	}
	return hist
}

pub fn print_histogram(s Stats) {
	mut hist := prepare_histogram(s)

	println("${'Index':5} ${'Instruction':20} ${'Count':14} ${'Elapsed':16} ${'Avg. elapsed':16}")
	println("-".repeat(5) + " " + "-".repeat(20) + " " + "-".repeat(14) + " " + "-".repeat(16) + " " + "-".repeat(16))
	hist.sort(a.elapsed > b.elapsed)
	for i, e in hist {
		count := thousand_grouping(u64(e.count), `,`)
		elapsed := thousand_grouping(e.elapsed, `,`)
		println("${i + 1:5} ${e.opcode:20} ${count:14} ${elapsed:16} ${e.avg_elapsed:16}")
	}
	println("-".repeat(5) + " " + "-".repeat(20) + " " + "-".repeat(14) + " " + "-".repeat(16) + " " + "-".repeat(16))
}

pub fn str_duration(d u64) string {
	if d < 10_000 { return "${thousand_grouping(d, `,`)} ns" }

	mut x := d / 1_000
	if x < 10_000 { return "${thousand_grouping(x, `,`)} µs" }

	x = x / 1_000
	if x < 10_000 { return "${thousand_grouping(x, `,`)} ms" }

	x = x / 1_000
	return "${thousand_grouping(x, `,`)} s"
}

pub fn thousand_grouping(n u64, sep byte) string {
	if n < 1_000 { return "${n}" }
	rtn := thousand_grouping(n / 1_000, sep)
	return rtn + ",${n % 1000:03}"
}
