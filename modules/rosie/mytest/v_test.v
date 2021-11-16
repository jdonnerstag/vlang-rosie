module mytest
/*
$if linux {
	#include "limits.h"
}

pub const uchar_max = C.UCHAR_MAX
*/
const bits_per_char = 8
const xyz = ((uchar_max / bits_per_char) + 1) // == 32

fn test_knowns() ? {
	assert bits_per_char == 8
	assert uchar_max == 255
	//assert xyz == 32	// TODO There is a bug in V !!!
}
