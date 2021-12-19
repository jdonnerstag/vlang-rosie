// 'mut' DOES NOT mean the variable can not be modified

struct AnotherStruct {
mut:
	str string
}

[params]
pub struct MyOptions {
	data &AnotherStruct
}

pub fn fn_test(args MyOptions) {
	assert args.data.str == "test"
	// args.str = "new"   // Compiler error. args.str is immutable
	mut x := args.data
	x.str = "why is this possible?"
	assert x.str == "why is this possible?"
	assert args.data.str == "why is this possible?"
}

fn test_1() {
	fn_test(data: &AnotherStruct{ str: "test" })
}
