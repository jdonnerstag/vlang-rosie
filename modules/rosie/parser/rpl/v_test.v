module rpl

struct MyIter {
mut:
	ar []int
	pos int
}

fn (mut m MyIter) next() ? int {
	for m.pos < m.ar.len {
		x := m.ar[m.pos]
		m.pos ++
		if x >= 5 { return x }
	}
	return error('')
}

type Intar = []int

fn (i Intar) my_filter() MyIter {
	return MyIter{ ar: i, pos: 0 }
}

fn test_iters() ? {
	data := Intar([1, 2, 5, 9, 3, 6, 0])
	//for x in data.my_filter() {	// conflicts with built-in filter() function
	for x in data.my_filter() {
		eprintln("x: $x")
	}

	mut iter := data.my_filter()
	for x in iter {
		eprintln("x: $x => $iter.pos")
	}
}

struct Inner { str string }

struct Outer { inner Inner }

fn (o &Outer) inner() &Inner { return &o.inner }

fn test_ptr() ? {
	outer := Outer{}
	ptr := outer.inner()
	eprintln("${voidptr(&outer)}: ${voidptr(&outer.inner)} == ${voidptr(outer.inner())}; ${voidptr(ptr)}; ${typeof(ptr).name}")
	assert ptr_str(voidptr(&outer.inner)) == ptr_str(outer.inner())
}