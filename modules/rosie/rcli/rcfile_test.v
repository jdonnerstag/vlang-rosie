module rcli

import os
import rosie

fn test_replace_env() {
	mut env := os.environ()
	assert replace_env(env, r"abc") == "abc"

	env = { "ABC": "abc", "ROSIE_HOME": "/home/rosie" }
	assert replace_env(env, r"abc") == "abc"
	assert replace_env(env, r"$ABC") == "abc"
	assert replace_env(env, r"-$ABC") == "-abc"
	assert replace_env(env, r"-$ABC-") == "-abc-"
	assert replace_env(env, r"$ABC-") == "abc-"
	assert replace_env(env, r"$ABC-$ROSIE_HOME") == "abc-/home/rosie"
}

fn test_rcfile() ? {
	mut rosie := rosie.init_rosie() ?
	import_rcfile(mut rosie, ".rosierc")?
}