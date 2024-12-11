local function agent_service()
    local skynet = require "skynet"
    local util_table = require "util.table"

    local m = {}

    -- 服务启动时注册自己需要加载哪些配置
    local staticdata = require "staticdata"
    staticdata.init "agent"

    function m.test(source)
        -- 使用 staticdata.get 接口取配置，不缓存配置到本地
        local data = staticdata.get "data/test/data1.lua"
        skynet.error("agent test data:", util_table.tostring(data))
    end

    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = assert(m[cmd])
        skynet.ret(skynet.pack(f(...)))
    end)
end

local function login_service()
    local skynet = require "skynet"
    local util_table = require "util.table"

    local m = {}

    -- 服务启动时注册自己需要加载哪些配置
    local staticdata = require "staticdata"
    staticdata.init "login"

    function m.test(source)
        -- 使用 staticdata.get 接口取配置，不缓存配置到本地
        local data = staticdata.get "data/test/data2.lua"
        skynet.error("login test data:", util_table.tostring(data))
    end

    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = assert(m[cmd])
        skynet.ret(skynet.pack(f(...)))
    end)
end

local service = require "skynet.service"
local skynet = require "skynet"

skynet.start(function()
    local staticdata = require "staticdata"
    staticdata.loadfiles()

    local cnt = 1
    local agents = {}
    for i = 1, cnt do
        local name = "agent-" .. i
        agents[i] = service.new(name, agent_service)
        skynet.call(agents[i], "lua", "test")
    end

    local logins = {}
    for i = 1, cnt do
        local name = "login-" .. i
        logins[i] = service.new(name, login_service)
        skynet.call(logins[i], "lua", "test")
    end

    skynet.sleep(3000)
    -- 在 sleep 中途去改变配置测试

    local arrlist = {
        "data/test/data1.lua",
        "data/test/data2.lua",
    }
    staticdata.update(arrlist)

    for i = 1, cnt do
        skynet.call(agents[i], "lua", "test")
        skynet.call(logins[i], "lua", "test")
    end
end)
