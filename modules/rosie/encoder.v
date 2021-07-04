module rosie

// TODO Maybe make Encoder an interface, and provide implementations 
// for Json, noop, etc.

type FnEncoderOpen = fn (cs &CapState, buf &Buffer, count int) int
type FnEncoderClose = fn (cs &CapState, buf &Buffer, count int, start int)

pub struct Encoder {  
  	open FnEncoderOpen
  	close FnEncoderClose
}

pub fn json_open(cs &CapState, buf &Buffer, count int) int {
	println("json_open(...)")
	return 0
}

pub fn json_close(cs &CapState, buf &Buffer, count int, start int) {
	println("json_close(...)")
}
