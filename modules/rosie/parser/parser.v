module parser

import rosie
import rosie.parser.core_0
import rosie.parser.rpl as rpl_1_3
import rosie.parser.rpl_3_0

// MasterParser In order to support the "rpl x.y" statement and dynamically
// switch to the required parser, a MasterParser is necessary.
pub struct MasterParser {
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
	}

	if args.rpl_file.len > 0 || args.rpl.len > 0 {
		pd.parse(file: args.rpl_file, data: args.rpl)?
	}

	return pd
}

fn new_parser_by_rpl_version(args CreateParserOptions) ? rosie.Parser {
	if args.language == "core_0" {
		// This is a work-around to explicitly get a core_0 parser
		p := core_0.new_parser(
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
		pd.parser.parse(file: args.file, data: args.data) or {
			if err.code == rosie.err_rpl_version_not_supported {
				main := pd.parser.main
				pd.language = main.language
				pd.parser = new_parser_by_rpl_version(
					language: pd.language,
					package_cache: pd.package_cache,
					libpath: pd.import_path
				)?
				pd.parser.main = main
				return pd.parser.parse(file: args.file, data: args.data)
			}
			return err
		}
	}
}
