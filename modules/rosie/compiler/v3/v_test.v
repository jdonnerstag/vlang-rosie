
fn test_a() {
	mut a := App{}
	a.data << 1
	a.do_something()
	//assert a.data.len == 2
}

struct App {
pub mut:
	data []int
}

fn (mut a App) do_something() {
	assert a.data.len == 1
	mut p := Proc{}
	p.make_a(mut a.data)
	//assert a.data.len == 2
}

struct Proc {}

fn (mut p Proc) make_a(mut data []int) {
	data << 2
}

struct Aaa {}

struct Bbb {
	Aaa
}

fn (a Aaa) aa() { println("aaa") }

//fn (a Aaa) cc() { a.bb() }

fn (b Bbb) bb() { println("bbb") }

fn (b Bbb) aa() { println("bb aa") }

fn test_embedded_structs() ? {
	b := Bbb{}
	b.aa()
	b.bb()
}