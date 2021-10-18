module cli

import os
import cli

pub fn cmd_config(cmd cli.Command) ? {
	rosie := init_rosie_with_cmd(cmd) ?

	exe := os.base(os.executable())
	libpath := rosie.libpath.join(os.path_delimiter)
	colors := rosie.colors.join(':')

	println('  ROSIE_VERSION = "$rosie.version"')
	println('     ROSIE_HOME = "$rosie.home"')
	println('  ROSIE_COMMAND = "$exe"')
	println('  ROSIE_LIBPATH = "$libpath"')
	println('   ROSIE_COLORS = "$colors"')
}
