# Rosie RPL benchmarks

- Be able to test performance of components individually, e.g. runtime vs. compiler
- Be able to test performance optimized byte code for specific pattern (micro benchmark)
- Append results to benchmark history file, in order to visualize performance trends
- We may add more benchmarks in the future. The approach should be flexible regarding these modifications
- Make sure that warm-up, etc. are properly considered, and that sufficiently large number of repetitions are executed
- Avoid to include "read from disc" and other unpredictable factors. Load data into mem beforehand if possible.
- It should be possible to execute these perf-test with every "release" (whatever that exactly will be), to
   validate how performance is changing in every release.
- But we also want to run perf test any time in between. Only that the entries added here, should not be
   committed to git.  May be some cli -prod flag?
- Perf logs should be committed to git, but only upon a new release (-prod flag)
- we may have multiple, very different, benchmarks. They should maintain their own log files
- but multiple similar benchmarks should write into the same log.
- the benchmark log file should be simple to read by any tool, incl. tools that are able to visualize them. May be CSV?
- But the log format must be flexible regarding extensions / new benchmarks
- name, date/time start execution, end-execution, number of repetitions, min, avg, max, std dev, 5%, 10%, ... See other histograms and benchmark programs for what has proven to be useful info.
- May be should be able to differentiate between many more stats for a single execution (profiler), vs. (release) performance monitoring.
- See https://github.com/vlang/v/blob/master/doc/docs.md#profiling for V support
- it would be useful to know which vm byte code instructions were executed how often, and how long it took

# Approach
