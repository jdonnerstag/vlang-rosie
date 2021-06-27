module runtime


fn test_new_ktable() ? {
   mut kt := new_ktable()
   assert kt.len() == 0
   kt.sort()
   kt.compact()
   assert kt.len() == 0
   if _ := kt.search("aaa") { assert false }

   kt.add("aaa")
   kt.sort()
   kt.compact()
   assert kt.len() == 1
   assert kt.get(0) == "aaa"
   assert kt.search("aaa")? == 0
   if _ := kt.search("bbb") { assert false }

   kt.add("ccc")
   kt.sort()
   kt.compact()
   assert kt.len() == 2
   assert kt.get(0) == "aaa"
   assert kt.get(1) == "ccc"
   assert kt.search("aaa")? == 0
   assert kt.search("ccc")? == 1
   if _ := kt.search("bbb") { assert false }

   kt.add("bbb")
   kt.sort()
   kt.compact()
   assert kt.len() == 3
   assert kt.get(0) == "aaa"
   assert kt.get(1) == "bbb"
   assert kt.get(2) == "ccc"
   assert kt.search("aaa")? == 0
   assert kt.search("bbb")? == 1
   assert kt.search("ccc")? == 2
   if _ := kt.search("ddd") { assert false }
}
