module vlang

import os

fn set_vmodules() {
	env := "VMODULES"
	mut val := os.getenv_opt(env) or { os.join_path("${@VMODROOT}", "modules") }
	val += os.path_delimiter
	val += os.join_path("${@VMODROOT}", "temp", "gen", "modules")
	eprintln("vmodules: $val")
	os.setenv(env, val, true)
}

fn test_compile() ? {
	set_vmodules()
	res := os.execute("${@VEXE} -cg test ./temp/gen/modules/mytest/my_test.v")
	assert res.exit_code == 0
	println(res.output)
}