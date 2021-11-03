module rcli

import strconv
import rosie

const color_map = {
	"default": 0
	"reset": 0
	"bold": 1
	"italic": 3
	"underline": 4
	"slow_blink": 5
	"rapid_blink": 6
	"black": 30
	"red": 31
	"green": 32
	"yellow": 33
	"blue": 34
	"magenta": 35
	"cyan": 36
	"white": 37
	"bright_black": 90
	"bright_red": 91
	"bright_green": 92
	"bright_yellow": 93
	"bright_blue": 94
	"bright_magenta": 95
	"bright_cyan": 96
	"bright_white": 97
	"bg_black": 40
	"bg_red": 41
	"bg_green": 42
	"bg_yellow": 43
	"bg_blue": 44
	"bg_magenta": 45
	"bg_cyan": 46
	"bg_white": 47
	"bg_bright_black": 100
	"bg_bright_red": 101
	"bg_bright_green": 102
	"bg_bright_yellow": 103
	"bg_bright_blue": 104
	"bg_bright_magenta": 105
	"bg_bright_cyan": 106
	"bg_bright_white": 107
}

pub fn color_to_esc(str string) string {
	mut rtn := "\x1b["
	ar := str.split(";")
	for i, e in ar {
		if i > 0 { rtn += ";" }
		if e in color_map {
			rtn += color_map[e].str()
		} else if _ := strconv.parse_int(e, 10, 0) {
			rtn += e
		} else {
			panic("term color: invalid color expression: '$e' in '$str'")
		}
	}
	rtn += "m"
	return rtn
}

pub fn colorize(col_esc string, str string) string {
	return col_esc + str + "\x1b[0m"
}

pub fn color_repr(c rosie.Color) string {
	mut rtn := c.key
	if c.startswith { rtn += "*"}
	rtn += "="
	//rtn += c.esc_str.replace("\x1b", r"\x1b")
	for i, x in c.esc_str.split(":") {
		if i > 0 { rtn += ":" }
		e := x[2 .. x.len - 1]
		for j, y in e.split(";") {
			if j > 0 { rtn += ";" }
			rtn += color_reverse_lookup(y.int()) or { y }
		}
	}
	return rtn
}

pub fn color_ar_repr(ar []rosie.Color) string {
	mut rtn := ""
	for i, c in ar {
		if i > 0 { rtn += ":" }
		rtn += color_repr(c)
	}
	return rtn
}

fn color_reverse_lookup(idx int) ?string {
	for k, v in color_map {
		if v == idx {
			return k
		}
	}
	return none
}
