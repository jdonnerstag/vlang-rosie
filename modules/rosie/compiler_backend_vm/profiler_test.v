module compiler_backend_vm

import rosie.runtime_v2 as rt


fn prepare_test(rpl string, name string, debug int) ? rt.Rplx {
    eprintln("Parse and compile: '$rpl' ${'-'.repeat(40)}")
    rplx := parse_and_compile(rpl: rpl, name: name, debug: debug, unit_test: false)?
    if debug > 0 { rplx.disassemble() }
	return rplx
}

fn test_simple_01() ? {
    rplx := prepare_test('"a" "b"', "*", 0)?
    mut line := ""
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    rt.print_histogram(m.stats)

    line = "a"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    rt.print_histogram(m.stats)

    line = "ab"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == false
    rt.print_histogram(m.stats)

    line = "a b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    rt.print_histogram(m.stats)

    line = "a bc"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    rt.print_histogram(m.stats)

    line = "a b c"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    rt.print_histogram(m.stats)

    line = "a  \t b"
    m = rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    rt.print_histogram(m.stats)
}

fn test_net_ipv6() ? {
    rplx := prepare_test('import net; net.ipv6', "*", 0)?
    mut line := "::FFFF:129.144.52.38"
    mut m := rt.new_match(rplx, 0)
    assert m.vm_match(line) == true
    rt.print_histogram(m.stats)
}
/* */