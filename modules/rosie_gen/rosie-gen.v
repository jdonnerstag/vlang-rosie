module rosie_gen

pub fn vrosie_match_main(input string, ipos int) bool {
	mut pos := ipos
	open_capture('main.*')
	for pos < input.len && input[pos] == 97 {
		pos++
	}
	close_capture()
	return true
}
