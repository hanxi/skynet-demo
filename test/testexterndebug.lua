local service = require "skynet.service"
local skynet = require "skynet"
local util_table = require "util.table"

local function test_service()
    local skynet = require "skynet"

    local CMD = {}
    local t = {}
    function CMD.test1()
        local t1 = {
            a = 1,
            b = 2,
        }
        t.t1 = t1
        skynet.error "in test1"
    end
    function CMD.test2()
        local t2 = {
            c = 3,
        }
        t.t2 = t2
        skynet.error "in test2"
    end
    skynet.dispatch("lua", function(_, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            log.error(string.format("Unknown cmd:%s, source:%s", cmd, source))
        end
    end)
end

skynet.start(function()
    skynet.newservice("debug_console", 8000)
    local address = service.new("test", test_service)
    local source = [[
        local extern_debug = require "extern_debug"
        extern_debug.init()
    ]]
    local ok, output = skynet.call(address, "debug", "RUN", source, "inject_extern_debug")
    if ok == false then
        error(output)
    end
    skynet.error(output)

    local ret0 = skynet.call(address, "debug", "SNAPSHOT")
    skynet.error("ret0:", util_table.tostring(ret0))

    skynet.call(address, "lua", "test1")
    local ret1 = skynet.call(address, "debug", "SNAPSHOT")
    skynet.error("ret1:", util_table.tostring(ret1))

    skynet.call(address, "lua", "test2")
    local ret2 = skynet.call(address, "debug", "SNAPSHOT")
    skynet.error("ret2:", util_table.tostring(ret2))
end)
