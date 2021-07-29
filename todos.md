
- The parser does not execute "import". It parses the statement, but doesn't import them (into a separate namespace)
- The parser currently always returns a group, because it doesn't know upfront (e.g. "a" "b").
    We should apply a simple optimization to remove it, if it has 1 child only.
    May we do this not only root, but for any group returned upon creation.
- The builtins are not yet available incl. ".", "$", "^", "~"
- I don't yet understand how to switch between non-ascii and ascii mode. At least word-boundary and "." have
    different meanings, and probably make testing more easy at the beginning.
- In compiler backend we test against the byte code generated. May be it would be more suitable to actually do a match
    and compare the captures. Especially since we may not apply the same optimizations that the original compiler does.
- the utf-8 rpl files has plenty of '[\\x12][\\x34]'. It should return a char resp. string for multiple consequitive ones,
    rather then a (multiple) charsets
- functions/macros are not yet implemented at all, e.g. find, findall, ci, keepto, ...
- meesages and errors are not yet implemented
- backref is not yet implemented
