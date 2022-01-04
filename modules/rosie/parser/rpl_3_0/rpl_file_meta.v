module rpl_3_0

import os
import rosie

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

fn (mut p Parser) find_and_load_package(name string) ? &rosie.Package {
	fpath := p.find_rpl_file(name)?

	if pkg := p.main.package_cache.get(fpath) {
		return pkg
	}

	if p.debug > 10 {
		eprintln(">> Import: load and parse '$fpath'")
		defer { eprintln("<< Import: load and parse '$fpath'") }
	}

	mut p2 := p.clone()
	p2.parse(file: fpath) or {
		return error("${err.msg}; file: $fpath")
	}

	return p2.main
}

fn (mut p Parser) import_package(alias string, name string) ? {
	pkg := p.find_and_load_package(name) or {
		return error("RPL parser: Failed to import package '$name': $err.msg")
	}

	p.main.imports[alias] = pkg
}
