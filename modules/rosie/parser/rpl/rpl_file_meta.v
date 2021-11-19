module rpl

import os


fn (mut p Parser) find_rpl_file(name string) ? string {
	if name.ends_with(".rpl") {
		return p.find_rpl_file(name[0 .. name.len - 4])
	}

	if name.len == 0 {
		return error("Import name must not be empty. File=$name")
	}

	for path in p.import_path {
		if f := p.find_rpl_file_("${path}/${name}") {
			return f
		}
	}

	if f := p.find_rpl_file_(name) {
		return f
	}

	return error("Import package: File not found: name='$name', path=${p.import_path}. ")
}

fn (mut p Parser) find_rpl_file_(name string) ? string {
	if os.is_file(name) {
		return os.real_path(name)
	}

	fp := "${name}.rpl"
	if os.is_file(fp) {
		return os.real_path(fp)
	}

	return none
}

fn (mut p Parser) find_and_load_package(name string) ?string {
	fpath := p.find_rpl_file(name)?
	eprintln("fpath: $fpath")

	if p.package_cache.contains(fpath) {
		eprintln("already imported: $fpath")
		return fpath
	}

	if p.debug > 10 {
		eprintln(">> Import: load and parse '$fpath'")
		defer { eprintln("<< Import: load and parse '$fpath'") }
	}

	pkg_name := name.all_after_last("/").all_after_last("\\")
	mut p2 := new_parser(
		rpl_type: .rpl_module,
		package: pkg_name,
		pkg_fpath: fpath,
		debug: p.debug,
		package_cache: p.package_cache
	) or {
		return error("new_parser() failed: ${err.msg}; file: $fpath")
	}
	p2.parse(fpath) or {
		return error("parse() failed: ${err.msg}; file: $fpath")
	}

	return fpath
}

fn (mut p Parser) import_package(alias string, name string) ? {
	eprintln("import_package: $name")
	fpath := p.find_and_load_package(name) or {
		return error("RPL parser: Failed to import package '$name': $err.msg")
	}
	eprintln("Import package: alias: $alias, name: $name, fpath: $fpath")
	p.package().imports[alias] = fpath
}
