module parser

import os
import strconv
import rosie
import rosie.parser.core_0
import rosie.parser.rpl as rpl_1_3
import rosie.parser.rpl_3_0

pub struct ParserDelegate {
pub:
	package_cache &rosie.PackageCache
	parser rosie.Parser
	major int
	minor int
}

pub fn init_libpath() ? []string {
	rosie := rosie.init_rosie()?
	return rosie.libpath
}

[params]
pub struct CreateParserOptions {
	rpl_file string
	rpl string
	debug int
	package_cache &rosie.PackageCache = rosie.new_package_cache()
	libpath []string = init_libpath()?
}

pub fn new_parser(args CreateParserOptions) ? ParserDelegate {
	mut data := args.rpl
	if args.rpl.len == 0 && args.rpl_file.len > 0 {
		data = os.read_file(args.rpl_file)?
	}

	major, minor, pos := determine_rpl_version(data)?

	if major == 0 {
		// This is a work-around to explicitly get a core_0 parser
		return ParserDelegate {
			major: major
			minor: minor
			package_cache: args.package_cache
			parser: core_0.new_parser(
				debug: args.debug
				package_cache: args.package_cache
				libpath: args.libpath
			)?
		}
	}

	if major == 1 {
		return ParserDelegate {
			major: major
			minor: minor
			package_cache: args.package_cache
			parser: rpl_1_3.new_parser(
				debug: args.debug
				package_cache: args.package_cache
				libpath: args.libpath
			)?
		}
	}

	if major == 3 {
		return ParserDelegate {
			major: major
			minor: minor
			package_cache: args.package_cache
			parser: rpl_3_0.new_parser(
				debug: args.debug
				package_cache: args.package_cache
				libpath: args.libpath
			)?
		}
	}

	str := substr(data, pos, 20)
	return error("RPL error: Required RPL version not supported: ${major}.${minor}; rpl: '$str'")
}

fn substr(data string, p1 int, len int) string {
	mut pmax := p1 + len
	if pmax > data.len { pmax = data.len }
	str := data[p1 .. pmax]
	return str
}

fn rpl_error_msg(data string, pos int) string {
	mut str := substr(data, pos, pos + 20)
	str = str.replace("\n", r'\n').replace("\r", r'\r')
	return "RPL Error: Invalid 'rpl x.y' expression: '$str'"
}

fn parse_uint(data string, pos int) ? int {
	mut p2 := pos
	for ; (p2 < data.len) && data[p2].is_digit(); p2++ {}
	if p2 == pos {
		mut str := substr(data, pos, pos + 20)
		str = str.replace("\n", r'\n').replace("\r", r'\r')
		return error(rpl_error_msg(data, pos))
	}

	rtn := strconv.parse_uint(data[pos .. p2], 10, 16) or {
		return error(rpl_error_msg(data, pos))
	}

	return int(rtn)
}

fn determine_rpl_version(data string) ? (int, int, int) {
	pos := skip_header(data)
	if data[pos..].starts_with("rpl") {
		mut p2 := skip_whitespace(data, pos + 3)
		major := parse_uint(data, p2)?
		p2 += 2
		if major > 9 { p2++ }
		minor := parse_uint(data, p2)?
		return int(major), int(minor), pos
	}

	return 1, 3, 0	// Default: same as "rpl 1.3"
}

fn skip_header(data string) int {
	mut old := 0
	mut pos := 0
	for pos < data.len {
		pos = skip_comment(data, pos)
		pos = skip_whitespace(data, pos)
		if pos == old { break }
		old = pos
	}
	return pos
}

fn skip_comment(data string, p int) int {
	mut pos := p
	if data[pos] == `-` && data[pos + 1] == `-` {
		pos += 2
		for ; (pos < data.len) && (data[pos] !in [`\r`, `\n`]); pos++ { }
	}
	return pos
}

fn skip_whitespace(data string, p int) int {
	mut pos := p
	if data[pos].is_space() {
		pos += 1
		for ; (pos < data.len) && data[pos].is_space(); pos++ { }
	}
	return pos
}
