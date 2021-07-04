module rosie

/* Kinds of captures 
 *
 * Stored in 'offset', which is 32 bits (way more than we ever need).
 * We will use only the low 8 bits, assume a max of 256 capture types,
 * and reserve bit 8 to indicate a closing capture.
 */
// TODO Not convinced I like that "high bit" tweak
// TODO Any idea what the meaning of each kind is?
enum CapKind { 
  	rosie_cap
	rosie_const 
	backref
	close = 0x80	// high bit set
  	final			// will also have high-bit set
	close_const		// And this one as well.
}

fn (ck CapKind) name() string {
	return match ck {
		.rosie_cap { "Rosie-Cap" }
		.rosie_const { "Rosie-Const" }
		.backref { "Backref" }
		.close { "Close" }
		.final { "Final" }
		.close_const { "Close-Const" }
	}
}

[inline]
fn (cap CapKind) isopencap() bool { return (int(cap) & 0x80) == 0 }

[inline]
fn (cap CapKind) isclosecap() bool { return cap.isopencap() == false }

[inline]
fn (cap CapKind) isfinalcap() bool { return cap == .final }

[inline]
fn (cap CapKind) iscloseapp() bool { return cap == .close }

// --------------------------

struct Capture {
pub mut:
	name string			// Capture name 
  	capkind CapKind		// Capture kind
  	start_pos int		// input start position
  	end_pos int			// input end position
} 

[inline]
fn (cap Capture) isopencap() bool { return cap.capkind.isopencap() }

[inline]
fn (cap Capture) isclosecap() bool { return cap.capkind.isclosecap() }

[inline]
fn (cap Capture) isfinalcap() bool { return cap.capkind.isfinalcap() }

[inline]
fn (cap Capture) iscloseapp() bool { return cap.capkind.iscloseapp() }

fn (caplist []Capture) print() {
  	for i, cap in caplist {
		println("$i ${cap.name} (${cap.capkind.name()}) $cap.start_pos .. $cap.end_pos")
  	}      
}

pub fn (caplist []Capture) find(name string, input string) ?string {
	for cap in caplist {
		if cap.name == name {
			return input[cap.start_pos .. cap.end_pos]
		}
	}
	return none
}
