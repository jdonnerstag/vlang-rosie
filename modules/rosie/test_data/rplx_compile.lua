-- ---------------------------------------------------------------------------
-- compile rosie with "make LUADEBUG=1"
-- cli: ./rosie -D
-- > e = rosie.engine.new()
-- > e:loadfile('src/rpeg/test/data/syslog.rpl')
-- > e
-- > s00 = e:compile('s00')
-- > s00
-- > rosie.env.lpeg.saveRPLX(s00.pattern.peg, "simple_s00.rplx")
-- ---------------------------------------------------------------------------
-- Note: rosie rplx does not support multiple entry points. Hence 1 x file 
--       per expression is needed
-- Execute this file with: 'file="simple.rpl" smax=19 dofile("rplx_compile.lua")'
-- ---------------------------------------------------------------------------

assert(file, "You must provide a 'file' parameter")
assert(smax, "You must provide a 'smax' parameter")

e = rosie.engine.new()

e:loadfile(file)
bname = string.gsub(file, "(.*/)(.*)", "%2")
bname = string.gsub(bname, "(.*)[.](.*)", "%1")
print("bname: " .. bname)

os.execute("rm " .. bname .. "_*.rplx")

for i = 0, smax do
    local name = "s" .. string.format("%02d", i)
    local x = e:compile(name)
    rosie.env.lpeg.saveRPLX(x.pattern.peg, bname .. "_" .. name .. ".rplx")
end
