module v2

import os
import rosie

const (
	file_magic_number = "RPLX"
	rplx_file_min_version = 1
	rplx_file_max_version = 0
)

/* The below comments are from the original rosie C-code. Not sure how much
   they are relevant for the V implementation as well.

 TODO
  Add meta-data to binary files, including:
	module name (for debugging/information purposes)
	source file timestamp (st_mtimespec from stat(2), 16 bytes) and length (st_size, 8 bytes)
	maybe whether a non-standard prelude was used? would be good debugging info.
	line number (in source file) for each pattern

  Write compiled library files to:
	rplx subdirectory of source directory

  New import behavior for 'import X'
	For each directory D on the (ordered) libpath:
	  If D/X.rplx exists, load it
	  Elseif D/X.rpl exists, load D/rplx/D.rplx if not stale, else recompile

  If rplx subdirectory cannot be created or cannot be written to:
	Warn if log level is higher than "completely silent"

  Cache rpl expressions used at the CLI?  FUTURE, IF NEEDED.
	Possible approach: Could write temporary rplx files to a cache
	directory, with an index file.  The index could be an LRU list of
	n recent expressions (including any rpl given on the command
	line, and any imports, auto or explicit).  If the current CLI
	invocation matches the index entry exactly, AND the imports are
	not stale, then use the compiled file from the cache.

  New rosie CLI structure, based on command entered:
	match X.y    import X, and if compiled, then match using X.y
	grep X.y     dynamically load rpl compiler, compile findall:X.y, match [note 1]
	list *       import prelude as ., list patterns [note 4]
	list X.*     import X, list patterns
	test f1..fn  load each, compiling if necessary, extract tests
				 from source, run tests
	expand exp   dynamically load rpl compiler, do macro expansion, print
	trace exp    dynamically load rpl compiler, run trace, print [note 2]
	repl         dynamically load rpl compiler, invoke repl [note 3]

	compile f1..fn  dynamically load rpl compiler, compile and save each
	compile exp f   FUTURE (save f.rplx file with anonymous entry point)
	dis f1..fn      disassemble each of f1, ... fn [note 3]

  [1] Would be nice if the grep command did not need the compiler.
  This is an optimization that can be implemented later, by
  generating the find/findall code on the fly from a template.

  [2] Trace could eventually be much-enhanced, perhaps making use of
  the vm instructions (i.e. the compiled pattern).  It should become
  its own dynamically loadable module.

  [3] The repl and dis could be their own dynamically loadable
  modules as well. And dis is already a separate executable.

  [4] The prelude is statically linked with (compiled into) every
  module, so that each module's patterns run with the prelude that it
  was written for.

  New librosie structure, to reflect new rosie CLI structure:
	librosie.so    match, search (find), grep (findall), list, test,
				   expand, trace, compile (loading librosiec.so as needed)
	librosiec.so   compile (and save), repl, trace (requires librosiel.so)
	librosieo.so   output encoders that need lua (requires librosiel.so)
	librosiel.so   lua for rosie
*/

// Once everything is native in V, we might leverage's V built-in serialization.
// May be rename Rplx to ByteCode?
pub struct Rplx {
pub mut:
	file_version int			// file format version
	charsets []rosie.Charset
	symbols rosie.Symbols		// capture table
	entrypoints rosie.EntryPoints
	code []Slot				  	// code vector
}

// TODO Rename to eof()?? Even the name doesn't perfectly fit, everybody knows what it will do.
[inline]
fn (rplx Rplx) has_more_slots(pc int) bool { return pc < rplx.code.len }

[inline]
fn (rplx Rplx) slot(pc int) Slot { return rplx.code[pc] }

[inline]
fn (rplx Rplx) addr(pc int) int { return pc + int(rplx.slot(pc + 1)) }

fn (rplx Rplx) charset_str(pc int) string {
	return rosie.to_charset(&rplx.code[pc]).str()
}

fn (rplx Rplx) find_cs(cs rosie.Charset) ?int {
	for i, e in rplx.charsets {
		if cs.is_equal(e) {
			return i
		}
	}
	return error("Rosie VM: symbol not found: '${cs.repr()}'")
}

pub fn (mut rplx Rplx) add_cs(cs rosie.Charset) int {
	if idx := rplx.find_cs(cs) {
		return idx
	}

	len := rplx.charsets.len
	rplx.charsets << cs
	return len
}

pub fn (rplx Rplx) save(file string, replace bool) ? {
	if replace == false && os.exists(file) {
		return error("File already exists: '$file'")
	}

	//eprintln("Temp rplx file: $file")
	mut fd := os.open_file(file, "wb+")?

	defer {
		fd.close()
	}

	fd.write_string(file_magic_number)? 	// 4 bytes; no trailing \0. We want to be 32 bit aligned

	file_min_version := rplx_file_min_version	// TODO Obviously write_raw() is not working with constants
	file_max_version := rplx_file_max_version
	fd.write_raw(file_min_version)?
	fd.write_raw(file_max_version)?

	fd.write_raw(rplx.file_version)?

	fd.write_raw(rplx.charsets.len)?
	for ch in rplx.charsets {
		for x in ch.data {
			fd.write_raw(x)?
		}
	}

	fill_bytes := 0
	fd.write_raw(rplx.symbols.symbols.len)?
	for s in rplx.symbols.symbols {
		fd.write_raw(s.len)?
		fd.write_string(s)?
		mut offset := s.len & 0x3
		if offset != 0 { offset = 4 - offset }
		unsafe { fd.write_ptr(&fill_bytes, offset) }
	}

	fd.write_raw(rplx.entrypoints.entries.len)?
	for e in rplx.entrypoints.entries {
		fd.write_raw(e.start_pc)?
		fd.write_raw(e.name.len)?
		fd.write_string(e.name)?
		mut offset := e.name.len & 0x3
		if offset != 0 {
			offset = 4 - offset
			unsafe { fd.write_ptr(&fill_bytes, offset) }
		}
	}

	fd.write_raw(rplx.code.len)?
	for s in rplx.code {
		fd.write_raw(u32(s))?
	}

	fd.write_string(file_magic_number)?  // Close marker
}

fn read_fixed_string(data []byte, pos int, len int) (string, int) {
	unsafe { return tos(&data[pos], len), pos + len }
}

fn read_string(data []byte, pos int) (string, int) {
	len, p := read_int(data, pos)
	mut offset := len & 0x3
	if offset != 0 { offset = 4 - offset }
	unsafe { return tos(&data[p], len), p + len + offset }
}

fn read_int(data []byte, pos int) (int, int) {
	unsafe { return *&int(&data[pos]), pos + 4 }
}

pub fn rplx_load(file string) ? Rplx {
	data := os.read_bytes(file)?

	mut pos := 0
	mut str := ""
	str, pos = read_fixed_string(data, pos, 4)
	if str != file_magic_number {
		return error("Invalid file magix number. Expected to find '$file_magic_number'")
	}

	mut i := 0
	i, pos = read_int(data, pos)
	assert i == rplx_file_min_version
	i, pos = read_int(data, pos)
	assert i == rplx_file_max_version

	mut rplx := Rplx{}
	rplx.file_version, pos = read_int(data, pos)
	assert rplx.file_version == 0

	mut len := 0
	len, pos = read_int(data, pos)
	//eprintln("found $len charsets; pos=$pos")
	for _ in 0 .. len {
		mut cs := rosie.new_charset()
		for j in 0 .. 8 {
			i, pos = read_int(data, pos)
			cs.data[j] = u32(i)
		}
		rplx.charsets << cs
		//eprintln("Charset: ${cs.repr()}, pos=$pos")
	}

	len, pos = read_int(data, pos)
	//eprintln("found $len symbols; pos=$pos")
	for _ in 0 .. len {
		str, pos = read_string(data, pos)
		rplx.symbols.add(str)
		//eprintln("Symbol: '${str}', pos=$pos")
	}

	len, pos = read_int(data, pos)
	//eprintln("found $len entrypoints; pos=$pos")
	for _ in 0 .. len {
		i, pos = read_int(data, pos)
		str, pos = read_string(data, pos)
		rplx.entrypoints.add(name: str, start_pc: i)?
		//eprintln("Entrypoint: start_pc=$i, name='${str}', pos=$pos")
	}

	len, pos = read_int(data, pos)
	//eprintln("found $len slots; pos=$pos")
	for _ in 0 .. len {
		i, pos = read_int(data, pos)
		rplx.code << Slot(u32(i))
	}

	str, pos = read_fixed_string(data, pos, 4)
	if str != file_magic_number {
		return error("Invalid file close marker. Expected to find '$file_magic_number'")
	}

	return rplx
}