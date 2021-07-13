module runtime

import os

const (
	file_magic_number = "RPLX\000"  // C-string with trailing '\0'. TODO remove \0 in future version to better align with 32 bit boundaries
	rplx_file_min_version = 0
	rplx_file_max_version = 0
	little_endian = unsafe { (*(&int(file_magic_number.str))) == 0x58_4C_50_52 }
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

// Once everything is native in V, we might leverage's V built-in serialization
struct Rplx {
pub mut:
  	file_version int		// file format version
  	rpl_major int     		// rpl major version
  	rpl_minor int			// rpl minor version
  	ktable Ktable			// capture table
  	code []Slot		// code vector
}

// x86 CPUs are little endian, which is what is implemented here.
// Theorectically it is only needed for big-endian systems.
// Are there still some around? Worth the overhead?
fn (rplx Rplx) encode_int(i int) []byte {
	mut x := []byte{ len: 4 }
	if little_endian {
		x[0] = byte(i & 0xFF)
		x[1] = byte((i >> 8) & 0xFF)
		x[2] = byte((i >> 16) & 0xFF)
		x[3] = byte((i >> 24) & 0xFF)
	} else {
		x[3] = byte(i & 0xFF)
		x[2] = byte((i >> 8) & 0xFF)
		x[1] = byte((i >> 16) & 0xFF)
		x[0] = byte((i >> 24) & 0xFF)
	}
	return x
}

fn array_replace(mut data []byte, pos int, repl []byte) {
	for i, ch in repl {
		data[pos + i] = ch
	}
}

fn (rplx Rplx) metadata_block() ?[]byte {
	length := 64
	mut data := []byte{ cap: length }

	data << file_magic_number.bytes()
	data << rplx.encode_int(rplx.ktable.len())

	data << [byte(0), 0  0, 0]
	data << rplx.encode_int(length)  // not the length, but the position where the next block starts
	data << rplx.encode_int(rplx.file_version)
	data << rplx.encode_int(rplx.rpl_major)
	data << rplx.encode_int(rplx.rpl_minor)

	if data.len > length {
		return error("Header should not exceed $length bytes")
	}

	for _ in data.len .. length {
		data << byte(0)
	}

	return data
}

fn next_section(mut data []byte) {
	data << `\n`
	rem := 3 - (data.len & 3)	// 32 bit / 4 byte boundary aligned
	for _ in 0 .. rem { data << byte(0) }
}

// TODO I find the original rosie file format for ktable a little convoluted / over-complex
// I would simply write the C-strings, preceeded by the block len.
fn (rplx Rplx) ktable_block() []byte {
	mut data := []byte{ cap: 300 }

	// Add a placeholder for number of ktable bytes
	data << rplx.encode_int(0)

	// Concatenate the ktable entries (C-strings)
	for s in rplx.ktable.elems {
		data << s.bytes()
		data << byte(0)
	}

	// Update the placeholder with the real value
	array_replace(mut data, 0, rplx.encode_int(data.len - 4))

	// Next section
	next_section(mut data)

	// TODO Not sure why this section is needed at all ?!?
	// Add the number of ktable entries that are now following
	data << rplx.encode_int(rplx.ktable.len())

	// pos = The relativ index in the previous block, where the 'name' begins
	mut pos := 0
	for s in rplx.ktable.elems {
		data << rplx.encode_int(pos)
		data << rplx.encode_int(s.len)
		data << rplx.encode_int(0)
		pos += s.len + 1	// C-string, incl. '\0'
	}

	// Next section
	next_section(mut data)

	return data
}

fn (rplx Rplx) code_block() []byte {
	mut data := []byte{ cap: 300 }

  	data << rplx.encode_int(rplx.code.len)

	// TODO I think the original implementation has issues with big/little endian. Some ints are encoded, others are not.
	for slot in rplx.code {
		data << rplx.encode_int(int(slot))
	}

	next_section(mut data)
	return data
}

// TODO separate create_buffer and write to file. Easier to debug.
fn (rplx Rplx) save(fname string) ? {
	mut data := rplx.metadata_block()?
	data.grow_cap(4000)

	data << rplx.ktable_block()
  	data << rplx.code_block()

	os.write_file(fname, data.bytestr())?
}

fn (mut rplx Rplx) read_meta_data(mut buf Buffer, debug int) ? {
	if debug > 0 { eprintln("pos: $buf.pos; read meta data") }

	magic_number := buf.get(file_magic_number.len)?
	if magic_number.bytestr() != file_magic_number {
		return error("Invalid file magic number: '$magic_number'. Expected '$file_magic_number'")
	}

	has_meta := buf.get(4)? == [byte(0xff), 0xff, 0xff, 0xff]
	if has_meta == false {
		buf.pos -= 4
		return
	}

	rplx.file_version = buf.read_int()?
	rplx.rpl_major = buf.read_int()?
	rplx.rpl_minor = buf.read_int()?

	// Skip the remaining header section
	buf.pos = 32
}

fn (mut rplx Rplx) read_ktable(mut buf Buffer, debug int) ? {
	if debug > 0 { eprintln("pos: $buf.pos; read ktable") }

	ktable_entries := buf.read_int()?
	block_size := buf.read_int()?
	if debug > 2 { eprintln("pos: $buf.pos; ktable entries: $ktable_entries; block size: $block_size") }

	buf.next_section(debug)?

	mut bsize := (ktable_entries + 1) * (4 + 4 + 4)
	if debug > 2 { eprintln("pos: $buf.pos; read ktable elements: size: $bsize") }
	isize := (ktable_entries + 1) * 3
	mut elem_block := []int{ len: isize }
	for i in 0 .. isize {
		elem_block[i] = buf.read_int()?
	}

	buf.next_section(debug)?

	if debug > 2 { eprintln("pos: $buf.pos; read ktable names: size: $block_size") }
	block := buf.get(block_size)?
	if debug > 4 { eprintln("pos: $buf.pos; ktable block: '$block'") }
	for i in 1 .. (ktable_entries + 1) {
		pos := elem_block[i * 3 + 0]
		len := elem_block[i * 3 + 1]
		// TODO I think V should this ?!?!
		s := if (pos + len) == block.len {
			block[pos .. ].bytestr()
		} else {
			block[pos .. pos + len].bytestr()
		}
		if debug > 3 { eprintln("ktable entry: '$s'") }

		rplx.ktable.add(s)
	}

	buf.next_section(debug)?
}

fn (mut rplx Rplx) read_code(mut buf Buffer, debug int) ? {
	if debug > 0 { eprintln("pos: $buf.pos; read instructions") }

	len := buf.read_int()?
	for _ in 0 .. len {
		code := buf.read_int()?
		rplx.code << Slot(code)
	}

	buf.next_section(debug)?
}

pub fn load_rplx(fname string, debug int) ?Rplx {
	if debug > 0 { eprintln("read file: $fname") }
	mut buf := Buffer{ data: os.read_file(fname)?.bytes() }

	mut rplx := Rplx{}
	rplx.read_meta_data(mut buf, debug)?
	rplx.read_ktable(mut buf, debug)?
	rplx.read_code(mut buf, debug)?

	if debug > 0 { eprintln("pos: $buf.pos; finished reading rplx file") }
	return rplx
}

[inline]
pub fn (rplx Rplx) instruction_str(pc int) string {
	return rplx.code.instruction_str(pc, rplx.ktable)
}

[inline]
fn (rplx Rplx) has_more_slots(pc int) bool { return pc < rplx.code.len }

[inline]
fn (rplx Rplx) slot(pc int) Slot { return rplx.code[pc] }

[inline]
fn (rplx Rplx) addr(pc int) int { return int(pc + rplx.slot(pc + 1)) }

fn (rplx Rplx) charset_str(pc int) string {
	return rplx.code.to_charset(pc).str()
}
