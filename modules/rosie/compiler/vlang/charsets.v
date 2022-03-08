module vlang

import rosie


enum CharsetBEOptimizations {
	standard
	bit_7
	digits
}

struct CharsetBE {
mut:
	optimization CharsetBEOptimizations = .standard
	count int
pub:
	pat rosie.Pattern
	cs rosie.Charset
}

fn (cb CharsetBE) compile(mut c Compiler) ? string {
	//eprintln("RPL vlang compiler: CharsetBE: compile '$cb.text'")
	id := "cs_${c.current.name}_${c.constants.len}"
	data_ar := cb.cs.data.str()#[1 .. -1].split_nth(",", 2)
	data_str := "u32(${data_ar[0]}), ${data_ar[1]}"
	c.constants << "const ${id} = rosie.Charset{ data: [$data_str]! }\n"

	fn_name := c.pattern_fn_name()
	mut fn_str := c.open_pattern_fn(fn_name, cb.pat.repr())
	cmd := "m.match_charset($id)"
	fn_str += c.gen_code(cb.pat, cmd)
	fn_str += "if match_ == false { m.pos = start_pos } \n"
	fn_str += "return match_ }\n\n"
	c.close_pattern_fn(fn_name, fn_str)

	return "m.${fn_name}()"
}
