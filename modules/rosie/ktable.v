module rosie

// This is basically the original rosie C-code translated to V.
// All credits to Jamie A. Jennings for the original implementation.
//
// I decided to start the migration to V with the rosie runtime.

/* TODO: ktable holds constant captures (Crosieconst) but we want
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

/*
 * Capture table
 *
 * In lpeg, this is a Lua table, used as an array, with values of any
 * type.  In Rosie, the value type is always string.  In order to have
 * a Rosie Pattern Matching engine that can be independent of Lua, we
 * provide here a stand-alone ktable implementation.
 * 
 * Operations 
 *
 * new, free, element, len, concat
 *
 */

/*
 * 'block' holds consecutive null-terminated strings;
 * 'block[elements[i]]' is the first char of the element i;
 * 'blocknext' is the offset into block of the first free (unused) character;
 * 'element[next]' is the first open slot, iff len <= size;
 * 'size' is the number of slots in the element array, size > 0;
 *
 *  NOTE: indexes into Ktable are 1-based
 */

struct Ktable {
pub mut:
  	elems []string
}

fn new_ktable() Ktable {
	return Ktable{}
}

[inline]
fn (kt Ktable) len() int {
	return kt.elems.len
}

[inline]
fn (kt Ktable) get(i int) string {
	return kt.elems[i]
}

fn (kt Ktable) print() {
    for i, s in kt.elems {
        println("${i:4}: '$s'")
    }
}

/* 
 * Concatentate the contents of table 'kt1' into table 'kt2'.
 * Return the original length of table 'kt2' (or 0, if no
 * element was added, as there is no need to correct any index).
 */
fn (mut kt Ktable) concat(kt2 Ktable) int {
	// 1-based index !!
	for str in kt2.elems {
		kt.add(str)
	}
	return kt2.elems.len
}

/* 
 * Return index of new element (1-based). 
 * The array will be sorted and compacted (no duplicates)
 */
fn (mut kt Ktable) add(name string) {
	kt.elems << name
}

fn (mut kt Ktable) sort() {
	kt.elems.sort_with_compare(compare_strings)
}

fn (mut kt Ktable) compact() {
	kt.sort()
	mut i := 1
	for i < kt.elems.len {
		n1 := kt.elems[i - 1]
		n2 := kt.elems[i]
		if n1 == n2 {
			kt.elems.delete(i)
			continue
		}
		i ++
	}
}

/* Given a COMPACT, SORTED ktable, search for an element matching
   'target', returning its index or 0 (if not found).
*/
fn (kt Ktable) search(target string) ?int {
	for i, str in kt.elems {
		if str == target { return i }
	}
	return error("Not found")
}

fn (kt Ktable) str() string {
    mut str := "Ktable: size = ${kt.len()}\n"
    str += "contents: \n"
    for i, name in kt.elems {
      	str += "  ${i + 1}: '$name'\n"
    }
	return str
}

fn (kt Ktable) dumpx() {
	println(kt.str())
}
