module vlang

import rosie


struct AliasBE {
pub:
	pat rosie.Pattern
	name string
}

// TODO PLease see StringBE for some improvements

fn (cb AliasBE) compile(mut c Compiler) ? string {
	//eprintln("RPL vlang compiler: AliasBE: compile '$cb.name'")
	alias, new_current := c.current.get_bp(cb.name)?
	cmd := "m." + "cap_${alias.full_name()}()".replace(".", "_")

	str := c.gen_code(cb.pat, cmd)

	// TODO Also need to update and reset c.fn_name and c.fn_idx
	c.current = new_current
	if c.debug > 0 { eprintln("Compile: current='${new_current.name}'; ${alias.repr()}") }
	c.compile_binding(alias, false)?

	return str
}
