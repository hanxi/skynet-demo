local skynet = require "skynet"
local sharetable = require "skynet.sharetable"
local service = require "skynet.service"

local M = {}
local g_static = {}
local g_servicekey

-- 更新数据并广播给所有服务更新
function M.update(arrlist)
    for _,name in pairs(arrlist) do
        sharetable.loadfile(name)
    end
    local srvs = skynet.call(".launcher", "lua", "LIST")
    for k in pairs(srvs) do
        skynet.call(k, "debug", "sharetable_update", arrlist)
    end
end

-- 获取数据, 不能缓存在本地，每次都需要重新读取
function M.get(name)
    skynet.error("get:", name, g_static[name])
    return g_static[name]
end

-- 加载所有用到的配置
function M.loadfiles()
    local skynet = require "skynet"
    local sharetable = require "skynet.sharetable"
    local service2datalist = require "data.service2datalist"

    -- TODO: 用某种方式自动生成所有配表名字列表
    for _,names in pairs(service2datalist) do
        for name,_ in pairs(names) do
            sharetable.loadfile(name)
            skynet.error("loadfile:", name)
        end
    end
    skynet.error("loadfiles ok")
end

-- 初始化
function M.init(servicekey)
    g_servicekey = servicekey
    local service2datalist = require "data.service2datalist"
    local datalist = service2datalist[servicekey]
    -- 初始化加载配表
    for name,_ in pairs(datalist) do
        g_static[name] = sharetable.query(name)
        skynet.error("sharetable init data. name:", name)
    end
end

-- 在 preload 里调用
function M.preload()
    local function _init()
        -- TODO: 用某种方式自动生成所有配表名字列表
        -- TODO: service2datalist.lua 配置文件的热更走 inject
        local service2datalist = require "data.service2datalist"

        -- 注册 debug 命令
        local debug = require "skynet.debug"
        local staticdata = require "staticdata"
        local function sharetable_update(arrlist)
            if g_servicekey then
                skynet.error("sharetable_update", g_servicekey)
                local datalist = service2datalist[g_servicekey]
                for _,name in pairs(arrlist) do
                    if datalist[name] then
                        skynet.error("sharetable data update begin. name:", name, g_static[name])
                        g_static[name] = sharetable.query(name)
                        skynet.error("sharetable data update ok. name:", name, g_static[name])
                    end
                end
            end
            skynet.ret(skynet.pack(nil))
        end
        debug.reg_debugcmd("sharetable_update", sharetable_update)
    end
    skynet.init(_init)
end

return M
