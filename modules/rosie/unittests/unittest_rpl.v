module unittests

const unittest_rpl = '
	import id
	import word

	pat = id.id1
	subpat = {id.dotted / id.id1}

	slocal = "local"   -- local is a reserved word in RPL
	accept = "accepts"
	reject = "rejects"
	include = "includes" subpat
	exclude = "excludes" subpat
	input = word.q

	unittest = "--" "test" slocal? pat (accept / reject / include / exclude) {input ("," input)*}
'
