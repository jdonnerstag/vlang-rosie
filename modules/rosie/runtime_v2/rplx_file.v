module runtime_v2

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
// Symbols and Slots should go into some ByteCode struct, independent from the file.
pub struct Rplx {
pub:
  	file_version int		// file format version
  	rpl_major int       // rpl major version
  	rpl_minor int			  // rpl minor version
  	symbols Symbols			// capture table
  	code []Slot				  // code vector
}

// instruction_str Print the byte code instruction at the program counter (pc) position
// TODO Rename to repr(), to be more consistent across the project
[inline]
pub fn (rplx Rplx) instruction_str(pc int) string {
	return rplx.code.instruction_str(pc, rplx.symbols)
}

[inline]
pub fn (rplx Rplx) disassemble() {
    rplx.code.disassemble(rplx.symbols)
}

// TODO Rename to eof()?? Even the name doesn't perfectly fit, everybody knows what it will do.
[inline]
fn (rplx Rplx) has_more_slots(pc int) bool { return pc < rplx.code.len }

[inline]
fn (rplx Rplx) slot(pc int) Slot { return rplx.code[pc] }

[inline]
fn (rplx Rplx) addr(pc int) int { return int(pc + rplx.slot(pc + 1)) }

fn (rplx Rplx) charset_str(pc int) string {
	return rplx.code.to_charset(pc).str()
}
