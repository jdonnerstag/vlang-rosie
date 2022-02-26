
..\v\v.exe run rosie_cli.v compile -c vlang -o .\temp\gen\modules\mytest .\modules\rosie\compiler\vlang\chars_tests.rpl t1

set VMODULES=.\modules;.\temp\gen\modules

..\v\v.exe -keepc -cg test .\temp\gen\modules\mytest\chars_tests_test.v
