module rosie


interface Compiler {
mut:
	compile(name string) ?
}

pub struct DummyCompiler {}

pub fn (c DummyCompiler) compile(name string) ? {}