module text_scanner

pub enum Encodings {
	utf_32be // = "UTF-32BE"
	utf_32le // = "UTF-32LE"
	utf_16be // = "UTF-16BE"
	utf_16le // = "UTF-16LE"
	utf_8 // = "UTF-8"
}

pub fn detect_bom(str string) (Encodings, int) {
	if str.starts_with([byte(0x00), 0x00, 0xfe, 0xff].bytestr()) {
		return Encodings.utf_32be, 4
	} else if str.starts_with([byte(0x00), 0x00, 0x00].bytestr()) {
		return Encodings.utf_32be, 3
	} else if str.starts_with([byte(0xff), 0xfe, 0x00, 0x00].bytestr()) {
		return Encodings.utf_32le, 4
	} else if str.len > 1 && str[1..].starts_with([byte(0x00), 0x00, 0x00].bytestr()) {
		return Encodings.utf_32le, 4
	} else if str.starts_with([byte(0xfe), 0xff].bytestr()) {
		return Encodings.utf_16be, 2
	} else if str.starts_with([byte(0x00)].bytestr()) {
		return Encodings.utf_16be, 1
	} else if str.starts_with([byte(0xff), 0xfe].bytestr()) {
		return Encodings.utf_16le, 2
	} else if str.len > 1 && str[1..].starts_with([byte(0x00)].bytestr()) {
		return Encodings.utf_16le, 2
	} else if str.starts_with([byte(0xef), 0xbb, 0xbf].bytestr()) {
		return Encodings.utf_8, 3
	} else {
		return Encodings.utf_8, 0
	}
}
