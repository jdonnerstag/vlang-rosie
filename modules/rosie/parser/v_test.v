module parser

struct Axx { a int }
pub fn (a Axx) str() string { return "Axx" }

struct Bxx { b int }
pub fn (b Bxx) str() string { return "Bxx" }

type SumAB = Axx | Bxx

struct MyStruct { x SumAB }
pub fn (x MyStruct) str() string { return x.x.str() }

fn test_str() {
	a := Axx{ a: 1 }
	assert a.str() == "Axx"

	x := MyStruct{ x: a }
	assert x.x is Axx
	assert (x.x as Axx).a == 1
	// Raise a bug ticket
	//assert x.str() == "Axx"
}
