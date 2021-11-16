module mytest

$if linux {
	#include "limits.h"
}

pub const uchar_max = C.UCHAR_MAX
