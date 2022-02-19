module rosie

struct ArrayTreeElem {
pub mut:
	elem Pattern		// Embed the actual element
	id int				// The elem is part of an array. Every array has a unique sequence id
	level int			// The depth level of the array
}

struct ArrayTree {
pub mut:
	id int				// Current array ID
	last_id int
	level int			// Current level
	data []ArrayTreeElem
}

pub fn new_array_tree(cap int) ArrayTree {
	return ArrayTree{ data: []ArrayTreeElem{ cap: cap }}
}

pub fn (mut a ArrayTree) add(elem Pattern) {
	a.data << ArrayTreeElem{ id: a.id, level: a.level, elem: elem }
}

pub fn (mut a ArrayTree) incr_level() {
	// An entry representing the group's predicate, repetition, operator
	a.add(Pattern{})

	a.level += 1
	a.last_id += 1
	a.id = a.last_id
}

pub fn (mut a ArrayTree) decr_level() {
	if a.level == 0 {
		panic("ArrayTree: Unable to decrement level on root")
	}

	a.level -= 1
	a.id = a.parent(a.id)
}

fn (a ArrayTree) parent(id int) int {
	for i := a.data.len - 1; i >= 0; i-- {
		xid := a.data[i].id
		if xid < id {
			return xid
		}
	}
	panic("ArrayTree: root doesn't have a parent")
}

pub fn (a ArrayTree) len(id int) ? int {
	if id < 0 || id > a.last_id {
		return none		// impossible ID
	}

	mut count := 0
	for e in a.data {
		if e.id == id { count++ }
	}

	return count
}

fn (a ArrayTree) repr_(idx int) (int, string) {
	mut rtn := ""
	mut space := false
	mut i := idx
	for ; i < a.data.len; i++ {
		e := a.data[i]

		if space == true {
			rtn += " "
		} else {
			space = true
		}

		if e.elem.elem is NonePattern {
			ii, str := a.repr_(i + 1)
			i = ii
			rtn += "($str)"
		} else {
			rtn += e.elem.repr()
		}

		if (i + 1) < a.data.len && e.id != a.data[i + 1].id {
			break
		}
	}
	return i, rtn
}

pub fn (a ArrayTree) repr() string {
	_, str := a.repr_(0)
	return str
}
