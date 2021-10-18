module rosie

import os
import v.vmod

struct Rosie {
pub mut:
	version          string
	verbose          int
	profiler_enabled bool
	home             string
	libpath          []string
	colors           []string
	rpl              string
}

// init_rosie Used in library-mode
pub fn init_rosie() ?Rosie {
	env := os.environ()
	home := env['ROSIE_HOME'] or { '.' }
	libpath := if p := env['ROSIE_LIBPATH'] {
		p.split(os.path_delimiter)
	} else {
	 	['.', os.join_path(home, 'rpl')]
	}

	vm := vmod.decode(@VMOD_FILE) ?

	return Rosie{
		version: vm.version
		verbose: 0
		profiler_enabled: false
		home: home
		libpath: libpath
	}
}
