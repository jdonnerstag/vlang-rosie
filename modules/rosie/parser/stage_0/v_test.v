module stage_0

import os

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

fn test_map() ? {
	mut m := map[string]string{}
	m["a"] = r"c:\temp"
	assert m["a"] == r"c:\temp"
	assert m["a"] == os.join_path(r"c:\", "temp")
}