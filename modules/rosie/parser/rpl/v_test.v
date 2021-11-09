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