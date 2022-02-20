module rosie


interface Compiler {
mut:
	compile(name string) ?
}

[params]
pub struct FnNewCompilerOptions {
	rplx &Rplx = new_rplx()
	user_captures []string
	unit_test bool
	debug int
	indent_level int = 2
}
