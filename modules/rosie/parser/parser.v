module parser

import rosie
import rosie.parser.stage_0
import rosie.parser.rpl_1_3
import rosie.parser.rpl_3_0

// MasterParser In order to support the "rpl x.y" statement and dynamically
// switch to the required parser, a MasterParser is necessary.
pub struct MasterParser {
	debug int

pub mut:
	package_cache &rosie.PackageCache
	import_path []string

	parser rosie.Parser
	language string
}

pub fn init_libpath() ? []string {
	rosie := rosie.init_rosie()?
	return rosie.libpath
}

[params]
pub struct CreateParserOptions {
	rpl_file string
	rpl string
	language string = "1.3"
	debug int
	package_cache &rosie.PackageCache = rosie.new_package_cache()
	libpath []string = init_libpath()?
}

pub fn new_parser(args CreateParserOptions) ? MasterParser {
	mut pd := MasterParser {
		language: args.language
		package_cache: args.package_cache
		import_path: args.libpath
		parser: new_parser_by_rpl_version(args)?
		debug: args.debug
	}

	if args.rpl_file.len > 0 || args.rpl.len > 0 {
		pd.parse(file: args.rpl_file, data: args.rpl)?
	}

	return pd
}

fn new_parser_by_rpl_version(args CreateParserOptions) ? rosie.Parser {
	if args.language == "stage_0" {
		// This is a work-around to explicitly get a stage_0 parser
		p := stage_0.new_parser(
			debug: args.debug
			package_cache: args.package_cache
			libpath: args.libpath
		)?
		return rosie.Parser(p)
	}

	if args.language.len == 0 || args.language.starts_with("1.") {
		p := rpl_1_3.new_parser(
			debug: args.debug
			package_cache: args.package_cache
			libpath: args.libpath
		)?
		return p
	}

	if args.language.starts_with("3.") {
		p := rpl_3_0.new_parser(
			debug: args.debug
			package_cache: args.package_cache
			libpath: args.libpath
		)?
		return p
	}

	return error("RPL error: No parser found for RPL version: ${args.language}")
}

pub fn (mut pd MasterParser) parse(args rosie.ParserOptions) ? {
	if args.file.len > 0 || args.data.len > 0 {
		if pd.debug > 0 {
			eprintln("Master Parser: rpl='$pd.language'; file='$args.file'")
		}
		pd.parser.parse(file: args.file, data: args.data, ignore_imports: true) or {
			if pd.debug > 0 {
				eprintln("Parser error: code=$err.code")
			}
			if err.code == rosie.err_rpl_version_not_supported {
				main := pd.parser.main
				pd.language = main.language
				if pd.debug > 0 {
					eprintln("Master Parser: rpl='$pd.language'; file='$args.file'; need another parser")
				}
				pd.parser = new_parser_by_rpl_version(
					language: pd.language,
					package_cache: pd.package_cache,
					libpath: pd.import_path
					debug: pd.debug
				)?
				pd.parser.main = main
				pd.parser.parse(file: args.file, data: args.data, ignore_imports: true)?
			} else {
				return err
			}
		}

		pd.import_packages()?
	}
}

fn (mut pd MasterParser) import_packages() ? {
	if pd.debug > 10 {
		eprintln("MasterParser: Parse imports...")
	}

	for stmt in pd.parser.imports {
		pkg := pd.import_package(stmt) or {
			return error_with_code("RPL Import failure: $err.msg; file='$stmt.fpath'", err.code)
		}
		pd.parser.main.imports[stmt.alias] = pkg
	}

	if pd.debug > 10 {
		eprintln("MasterParser: Package='$pd.parser.main.name': Done with imports")
	}
}

fn (mut pd MasterParser) import_package(stmt rosie.ImportStmt) ? &rosie.Package {
	if pd.debug > 10 {
		eprintln("Package='$pd.parser.main.name'; Import file='$stmt.fpath', alias='$stmt.alias'")
	}

	mut pd_import := new_parser(
		language: pd.language
		package_cache: pd.package_cache
		debug: pd.debug
	)?

	if pkg := pd.package_cache.get(stmt.fpath) {
		return pkg
	}

	pd_import.parse(file: stmt.fpath, ignore_imports: true)?

	pkg := pd_import.parser.main
	pd.package_cache.add_package(pkg)?

	return pkg
}
