module vlang

import os

fn set_vmodules() ? {
	env := "VMODULES"
	mut val := os.getenv_opt(env) or { os.join_path("${@VMODROOT}", "modules") }
	val += os.path_delimiter
	val += os.join_path("${@VMODROOT}", "temp", "gen", "modules")
	os.setenv(env, val, true)
	eprintln("${env}: " + os.getenv_opt(env)? )
}

fn compile_cli() ? {
	eprintln("Compile: rosie_cli.v")
	res := os.execute("${@VEXE} rosie_cli.v")
	if res.exit_code != 0 { println(res.output) }
	assert res.exit_code == 0
}

fn compile_rpl_file(rpl_file string, out_dir string) ? {
	eprintln("Compile: $rpl_file")
	// TODO Evolve to "internally" compiling, rather then calling the CLI
	cmd := "rosie_cli.exe compile -c vlang -o $out_dir ${rpl_file} t1"
	eprintln("Exec: $cmd")
	res := os.execute(cmd)
	if res.exit_code != 0 { println(res.output) }
	assert res.exit_code == 0
}

fn exec_rpl_tests(vlang_test_file string) ? {
	eprintln("Execute tests: $vlang_test_file")
	cmd := "${@VEXE} -keepc -cg -stats test $vlang_test_file"
	eprintln("Exec: $cmd")
	res := os.execute(cmd)
	if res.exit_code != 0 { println(res.output) }
	assert res.exit_code == 0
}

fn compile_and_test(rpl_file string, out_dir string) ? {
	compile_rpl_file(rpl_file, out_dir)?

	vlang_test_file := os.join_path(out_dir, os.file_name(rpl_file).replace(".rpl", "_test.v"))
	exec_rpl_tests(vlang_test_file)?
}

fn test_rpl_test_files() ? {
	compile_cli()?
	set_vmodules()?

	out_dir := r".\temp\gen\modules\mytest"
	rpl_test_dir := "./rpl/rosie/tests"
	rpl_files := os.ls(rpl_test_dir)?.filter(it.ends_with("_tests.rpl"))
	for f in rpl_files {
		compile_and_test(os.join_path(rpl_test_dir, f), out_dir)?
		//break
	}
}
