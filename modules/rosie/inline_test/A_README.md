# Rosie unit tests

This module implements the logic run the in-document tests, which rosie supports.
It does not provide the CLI itself

E.g.
```
-- test thing includes word.any "face", "a"
-- test thing includes num.float "6.0", "-3.14"
-- test year accepts "1960", "1999", "2010", "9999"
-- test year rejects "99", "00", "12345", "year"
```

See [here](https://gitlab.com/rosie-pattern-language/rosie/-/blob/master/doc/unittest.md) for more details.
