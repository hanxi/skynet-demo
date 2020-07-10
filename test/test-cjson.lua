package.cpath = package.cpath .. ";luaclib/?.so"
local cjson = require "cjson"
local tbl = {
    a = 1,
    b = { 3, 2, 3, 4 },
}
print(cjson.encode(tbl))
