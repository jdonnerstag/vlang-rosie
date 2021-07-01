module rosie

// TODO Maybe make Encoder an interface, and provide implementations 
// for Json, noop, etc.

type FnEncoderOpen = fn (cs &CapState, buf &Buffer, count int) int
type FnEncoderClose = fn (cs &CapState, buf &Buffer, count int, start int)

pub struct Encoder {  
  	open FnEncoderOpen
  	close FnEncoderClose
}
