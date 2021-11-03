module rcli

import os
import cli
import rosie

pub fn cmd_config(cmd cli.Command) ? {
	flib := cmd.flags.get_bool('lib') ?

	rosie := if flib {
		rosie.init_rosie() ?
	} else {
		init_rosie_with_cmd(cmd) ?
	}

	exe := os.base(os.executable())
	libpath := rosie.libpath.join(os.path_delimiter)
	colors := color_ar_repr(rosie.colors)

	println('  ROSIE_VERSION = "$rosie.version"')
	println('     ROSIE_HOME = "$rosie.home"')
	println('  ROSIE_COMMAND = "$exe"')
	println('  ROSIE_LIBPATH = "$libpath"')
	println('   ROSIE_COLORS = "$colors"')

	color_test := cmd.flags.get_bool('color_test') ?
	if color_test {
		println("")
		println("Color Test:")
		println("-".repeat(60))
		for i, c in rosie.colors {
			mut k := c.key
			if c.startswith { k += "*" }
			str := colorize(c.esc_str, "This is a test")
			println("${i+1:3}: ${k:-20} = '$str'")
		}
		println("-".repeat(60))
	}
}
