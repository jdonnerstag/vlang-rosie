
struct MyStruct {
	a string
	b int
}

fn test_ar_ptr() ? {
	mut ar := map[string]&MyStruct{}
	ar["a"] = &MyStruct{}
	assert ("b" in ar) == false
	assert ("a" in ar) == true
	// assert "a" in ar
}