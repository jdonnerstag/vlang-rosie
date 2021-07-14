module compiler_backend

// Types of trees (stored in tree.tag)
enum TTag {
    tchar     // standard PEG elements
    tset      // standard PEG elements
    tany      // standard PEG elements
    ttrue
    tfalse
    trep
    tseq
    tchoice
    tnot
    tand
    tcall
    topencall
    trule      // sib1 is rule's pattern, sib2 is 'next' rule
    tgrammar   // sib1 is initial (and first) rule
    tbehind    // match behind
    tcapture   // regular capture
    truntime   // run-time capture
    tbackref   // Rosie: match previously captured text
    thalt      // Rosie: stop the vm (abend)
    tnotree    // Rosie: a compiled pattern restored from a file has no tree
}

fn (tag TTag) numsiblings() int {
    return match tag {
        .tchar { 0 }
        .tset { 0 }
        .tany { 0 }
        .ttrue { 0 }
        .tfalse { 0 }
        .trep { 1 }
        .tseq { 2 }
        .tchoice { 2 }
        .tnot { 1 }
        .tand { 1 }
        .tcall { 0 }
        .topencall { 0 }
        .trule { 2 }
        .tgrammar { 1 }
        .tbehind { 1 }
        .tcapture { 1 }
        .truntime { 1 }
        .tbackref { 0 }
        .thalt { 0 }
        .tnotree { 0 }
    }
}
