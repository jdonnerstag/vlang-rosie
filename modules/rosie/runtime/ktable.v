module runtime

/* The below comments are from the original rosie C-code. Not sure how much
   they are relevant for the V implementation as well.

   TODO: ktable holds constant captures (Crosieconst) but we want
   those to be unicode, and ktable cannot hold unicode because it is
   implemented using null-terminated strings.  In future, even rosie
   pattern names could be unicode, and that is what ktable was meant
   for.  So we should change the impl to store string length, too.

   ALSO: For ahead-of-time compilation (specifically, to produce
   library files), we need an index of entry points into a code
   vector. Since the entry points are pattern names, all of which are
   in the ktable, we will enhance the ktable to store an unsigned
   32-bit index into the instruction vector.  That index will be used
   by 'call' instructions.

   N.B. It's possible for two distinct captures to have the same
   capture name, and we compact the ktable to remove duplicates. It
   should NOT be possible for two entry points in the same namespace
   to have the same capture name, so we can continue to compact the
   ktable.  When consolidating multiple entries that have the same
   name, we should observe that only one of them has an entry point
   defined.

   New capture table format:
   'size' is the number of entries;
   'block' is a byte array that holds the capture names;
   'element' is an array of structures (see below);
   Each element contains:
   'start' is the first character of the capture name in 'block';
   'len' is the number of bytes in the capture name;
   'entrypoint' is an index into the code vector IFF this name is an entry point;

   Ktable indexing begins at 1, which reserves the 0th element for RPL
   library use.  The first element (at index 0) points to the default
   prefix name for the library, stored in 'block'.  When there is not
   a prefix (such as for a top-level namespace), the length field will
   be 0.
*/

// TODO may be rename to SymbolTable
// Ktable Very typical for compiled code, the byte code contains a symbol
// table for static string values. Virtual machine instructions reference
// such symbols by their posiiton / index.
struct Ktable {
pub mut:
  	elems []string
}

// new_ktable Create a new, empty, symbol table
fn new_ktable() Ktable { return Ktable{} }

// len I wish V-lang had the convention calling x.len actually invokes x.len()
// Determine the number of entries in the symbol table
[inline]
fn (kt Ktable) len() int { return kt.elems.len }

// get Access the n'th element in the symbol table
[inline]
fn (kt Ktable) get(i int) string { return kt.elems[i] }

// add Append an entry to the symbol table
// I wish V-lang had a convention that x << ".." invokes x.add("..")
[inline]
fn (mut kt Ktable) add(name string) { kt.elems << name }

// print Print the content of the symbol to stdout
[inline]
fn (kt Ktable) print() { println(kt.str()) }

// str Create a string representation of the symbol table
fn (kt Ktable) str() string {
    mut str := "Symbol table:\n"
    for i, name in kt.elems {
      	str += "${i + 1:4d}: '$name'\n"
    }
	return str
}
