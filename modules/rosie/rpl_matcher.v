module rosie

pub interface RplMatcher {

	has_match(pname string) bool

	get_match(path ...string) ?string

	get_all_matches(path ...string) ? []string

	print_captures(any bool)

	replace(repl string) string

	replace_by(name string, repl string) ?string
}
