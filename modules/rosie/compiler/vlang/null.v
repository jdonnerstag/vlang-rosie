module vlang

// This is only a dummy, until all BEs are implemented
struct NullBE {}

fn (cb NullBE) compile(mut c Compiler) ? string {
	return ""
}
