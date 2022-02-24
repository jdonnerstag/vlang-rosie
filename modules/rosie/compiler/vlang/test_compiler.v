module vlang

import os
import rosie.unittests

// Scan the input file for RPL unittests and create a Vlang equivalent
pub fn (mut c Compiler) create_test_cases(fname string) ? {
	out_fname := os.file_name(fname).replace(".rpl", "")
	out_file := "${c.target_dir}/${c.module_name}/${out_fname}_test.v"

	mut str := "module ${c.module_name}

// This is a generated file. Content might be overwritten without warning

// This test function is always generated. If nothing else, running the test
// will validate that the source code successfully compiles.
fn test_dummy__() ? {
}
"
	rpl_file := unittests.read_file(fname)?
	mut id := 0
	for test in rpl_file.tests {
		id += 1

		str += "\n// TODO <insert pattern repr here>  ${test.pat_repr}"
		str += "\nfn test_${test.pat_name}_${id}() ? {"

		if test.op == .accept {
			for i, inp in test.input {
				if i == 0 {
					str += "\nmut m := "
				} else {
					str += "\nm = "
				}
				str += "new_matcher('$inp')"
				str += "\nassert m.cap_${test.pat_name}() == true"
				str += "\nassert m.pos == ${inp.len}"
				str += "\n"
			}
		} else if test.op == .reject {
			for i, inp in test.input {
				if i == 0 {
					str += "\nmut rtn := false\nmut m := "
				} else {
					str += "\nm = "
				}
				str += "new_matcher('$inp')\n"
				str += "rtn = m.cap_${test.pat_name}() == true && m.pos == ${inp.len}\n"
				str += "assert rtn == false\n"
			}
		} else if test.op == .include {
			str += "\n    // Vlang generation for '$test.op' not yet implemented\n"
		} else if test.op == .exclude {
			str += "\n    // Vlang generation for '$test.op' not yet implemented\n"
		} else if test.op == .assertion {
			for i := 0; (i + 1) < test.input.len; i += 2 {
				if i == 0 {
					str += "\nmut m := "
				} else {
					str += "\nm = "
				}
				str += "new_matcher('${test.input[i]}')\n"
				str += "m.cap_${test.pat_name}()\n"
				str += "str := m.input[.. m.pos]\n"
				str += "assert str == '${test.input[i+1]}'\n"
			}
		} else {
			str += "\n    // Vlang generation for '$test.op' not yet implemented\n"
		}
		str += "}\n"
	}

	eprintln("Info: File generated: $out_file")
	os.write_file(out_file, str)?

	eprintln("INFO: Format files: $out_file")
	os.execute("${@VEXE} fmt -w $out_file")
}
