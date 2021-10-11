module cli

import os
import cli
import v.vmod
import strconv
import rosie
import rosie.compiler_backend_vm as compiler
import rosie.runtime_v2 as rt


// init_rosie_with_cmd Used in cli-mode
pub fn init_rosie_with_cmd(cmd cli.Command) ? rosie.Rosie {
    mut rosie := rosie.init_rosie()?

    env := os.environ()
    rosie.home = env["ROSIE_HOME"] or { os.dir(os.args[0]) }
    rosie.libpath = if p := env["ROSIE_LIBPATH"] {
        p.split(os.path_delimiter)
    } else {
        [".", os.join_path(rosie.home, "rpl")]
    }

    root := cmd.root()
    all_found_flags := root.flags.get_all_found()
	if _ := flag_provided(all_found_flags, "verbose") { rosie.verbose = 1 }
	if _ := flag_provided(all_found_flags, "profile") { rosie.profiler_enabled = true }

	if root.flags.get_bool("norcfile")? == false {
		mut rcfile := root.flags.get_string("rcfile")?
        if rcfile.len == 0 {
            import_rcfile_if_exists(mut rosie, os.home_dir(), ".rosierc") or {
                import_rcfile_if_exists(mut rosie, rosie.home, ".rosierc") or {}
            }
        } else {
            import_rcfile(mut rosie, rcfile)?
        }
    }

	if x := flag_provided(all_found_flags, "libpath") {
        rosie.libpath = x.get_string()?.split(os.path_delimiter)
    }

	if x := flag_provided(all_found_flags, "colors") {
    	rosie.colors := x.get_string()?.split(":")
    }

	rpl := root.flags.get_string("rpl")?
    if rpl.len > 0 {
        rosie.rpl += ";" + rpl
    }

	rpl_file := root.flags.get_string("file")?
    if rpl_file.len > 0 {
        rosie.rpl += os.read_file(rpl_file)
    }

    return rosie
}

fn flag_provided(flags []cli.Flag, name string) ? cli.Flag {
    for x in flags {
        // 'found' is private not accessible
	    if x.name == name /* && x.found */ { return x }
    }
    return error("Not found")
}

fn import_rcfile_if_exists(mut rosie rosie.Rosie, dir string, file string) ? {
    rcfile := os.join_path(dir, file)
    if os.is_file(rcfile) {
        import_rcfile(mut rosie, rcfile)?
    }
    return error("File not found")
}

fn import_rcfile(mut rosie rosie.Rosie, file string) ? {
    // Note: the 'commands' are not identical to the orig rosie impl.
    // Support:
    //   libpath        => replace
    //   add_libpath    => append
    //   verbose        => replace
    //   colors         => replace
    //   color          => update or add
    //   rpl            => append
    // Support env vars e.g. ROSIE_LIBPATH => libpath = "$ROSIE_HOME/rpl;$ROSIE_LIBPATH;c:/temp"

    data := $embed_file("./modules/rosie/cli/rcfile.rpl")
    rplx := compiler.parse_and_compile(rpl: data.to_string(), name: "options", debug: 0)?

    mut m := rt.new_match(rplx, 0)
    eprintln("RC-File: $file")

    rcdata := os.read_file(file)?
    m.vm_match(rcdata)
    //eprintln(m.captures)

    mut option_idx := 0
    for {
        option_idx = m.next_capture(option_idx, "rcfile.option", true) or { break }
        cap := m.captures[option_idx]
        if cap.matched == false {
			mut end := cap.start_pos + 40
			if end > m.input.len { end = m.input.len }
            if end > cap.start_pos {
                return error("rcfile: incomplete statement: '${m.input[cap.start_pos .. end]}'")
            }
            break
        }

        child_idx := m.child_capture(option_idx, option_idx, "id")?
        literal_idx := m.child_capture(option_idx, child_idx, "rpl_1_2.literal")?

        option_idx = literal_idx

        localname := m.captures[child_idx].text(m.input)
        literal := m.captures[literal_idx].text(m.input)
        eprintln("$localname = '$literal'")

        if localname == "libpath" {
            rosie.libpath = literal.split(os.path_delimiter)
        } else if localname == "add_libpath" {
            rosie.libpath << literal
        } else if localname == "verbose" {
            rosie.verbose = int(strconv.parse_int(literal, 10, 0)?)
        } else if localname == "colors" {
            rosie.colors = literal.split(":")
        } else if localname == "color" {
            rosie.colors << literal
        } else if localname == "rpl" {
            rosie.rpl += ";" + literal
        } else if localname == "file" {
            rosie.rpl += ";" + os.read_file(literal)?
        } else {
            eprintln("rcfile: invalid command '$localname' = '$literal'")
        }
    }
}
