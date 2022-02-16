module rosie

// Capture Often a pattern is made up of simpler pattern. The runtime captures them
// while parsing the input. It basically is the output of a matching process.
// Capture represents a single entry in a tree-like structure of Captures.
pub struct Capture {
pub:
	parent int			// The index of the parent capture in the list that mmatch is maintaining
	idx int				// Capture name (index)
	level int			// Captures are nested

pub mut:
	start_pos int		// input start position
	end_pos int			// input end position
	matched bool		// whether the input matched the RPL or not
	timer u64
}

[inline]
pub fn (c Capture) text(input string) string { return input[c.start_pos .. c.end_pos] }

[params]
pub struct CaptureFilter {
pub mut:
	captures []Capture
	pos int					// where to start (index) in the capture list
	count int
pub:
	any bool 				// if false, then matched captures only
	level int				// Capture level must be >= level, else finish
}

// TODO V has a builtin filter() function, which obviously can not be replaced my own one.
pub fn (c []Capture) my_filter(args CaptureFilter) CaptureFilter {
	return CaptureFilter{ ...args, captures: c }
}

pub fn (c CaptureFilter) clone() CaptureFilter {
	return CaptureFilter{ ...c }
}

pub fn (c CaptureFilter) any(any bool) CaptureFilter {
	return CaptureFilter{ ...c, any: any }
}

pub fn (c CaptureFilter) level(level int) CaptureFilter {
	return CaptureFilter{ ...c, level: level }
}

pub fn (c CaptureFilter) pos(pos int) CaptureFilter {
	return CaptureFilter{ ...c, pos: pos }
}

pub fn (c CaptureFilter) last() int {
	return c.pos - 1
}

pub fn (cf CaptureFilter) current() Capture {
	return cf.captures[cf.pos]
}

pub fn (mut cf CaptureFilter) next() ? Capture {
	for cf.pos < cf.captures.len {
		cap := cf.captures[cf.pos]
		cf.pos ++

		if cap.level < cf.level {
			break
		}

		if cap.level == cf.level {
			if cf.count != 0 { break }
			cf.count ++
		}

		if cf.any {
			return cap
		}

		if cap.matched {
			mut idx := cap.parent
			for cf.captures[idx].matched {
				if idx == 0 {
					return cap
				}
				idx = cf.captures[idx].parent
			}
		}
	}

	cf.pos = cf.captures.len
	return error('')
}

pub fn (mut cf CaptureFilter) peek_next() ? Capture {
	pos := cf.pos
	count := cf.count

	defer {
		cf.pos = pos
		cf.count = count
	}

	return cf.next()
}

pub fn (mut cf CaptureFilter) skip_subtree() {
	if cf.pos >= cf.captures.len {
		return
	}

	level := cf.captures[cf.pos - 1].level
	for ; cf.pos < cf.captures.len; cf.pos++ {
		cap := cf.captures[cf.pos]
		if cap.level <= level {
			break
		}
	}
}
