module runtime_v2

pub struct EntryPoint {
pub mut:
	name string
	start_pc int
}

pub struct EntryPoints {
pub mut:
	entries []EntryPoint
}

pub fn (mut ep EntryPoints) add(elem EntryPoint) ? int {
	if _ := ep.find(elem.name) {
		return error("RPL: Entrypoint with same name already exists: '$elem.name'")
	}

	len := ep.entries.len
	ep.entries << elem
	return len
}

pub fn (ep EntryPoints) find(name string) ? int {
	for e in ep.entries {
		if e.name == name || e.name.ends_with(".$name") {
			return e.start_pc
		}
	}
	return error("Rosie VM: entrypoint not not found: '$name'")
}

pub fn (ep EntryPoints) names() []string {
	mut ar := []string{}
	for e in ep.entries {
		ar << e.name
	}
	return ar
}

pub fn (ep EntryPoints) len() int {
	return ep.entries.len
}
