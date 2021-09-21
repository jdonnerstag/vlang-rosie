module cmd_config

import os
import rosie.cli.core


pub struct CmdConfig {
pub:
    version string
    home string
    libdir string
    command string
    libpath []string
    colors []string
}

const default_colors = [
    "*=default;bold",
    "net.*=red",
    "net.ipv6=red;underline",
    "net.url_common=red;bold",
    "net.path=red",
    "net.MAC=underline;green",
    "num.*=underline",
    "word.*=yellow",
    "all.identifier=cyan",
    "id.*=bold;cyan",
    "os.path=green",
    "date.*=blue",
    "time.*=1;34",
    "ts.*=underline;blue",
]

// TODO Add support .rosierc file
pub fn new_config() CmdConfig {
    home := os.dir(os.args[0])
    env := os.environ()
    libdir := env["ROSIE_LIBDIR"] or { os.join_path(home, "rpl") }
    libpath := if p := env["ROSIE_LIBPATH"] { p.split(os.path_delimiter) } else { [".", libdir] }

    return CmdConfig{
        //version: core.vmod_version,
        //home: home,
        //libdir: libdir,
        //command: os.base(os.executable()),
        //libpath: libpath,
        //colors: default_colors
    }
}

pub fn (c CmdConfig) run(main core.MainArgs) ? {
    libpath := "" //c.libpath.join(os.path_delimiter)

    // TODO There seems to be a (malloc) bug in V and the compiler fails with the following command.
    //colors := c.colors.join(":")
    mut colors := ""
    //for i, col in c.colors { colors += if i == 0 { col } else { ":$col" } }
    //for i, col in default_colors { colors += if i == 0 { col } else { ":$col" } }
    //colors := default_colors.join(":")

    //println('  ROSIE_VERSION = "$c.version"')
    //println('     ROSIE_HOME = "$c.home"')
    //println('   ROSIE_LIBDIR = "$c.libdir"')
    println('  ROSIE_COMMAND = "$c.command"')
    println('  ROSIE_LIBPATH = "$libpath"')
    println('   ROSIE_COLORS = "$colors"')
}
