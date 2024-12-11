local skynet = require "skynet"

local M = {}
local service_list
local service_max
local cur_idx = 0

local function get_snowflake_addr()
    cur_idx = cur_idx + 1
    if cur_idx > service_max then
        cur_idx = 1
    end
    return service_list[cur_idx]
end

function M.snowflake()
    local addr = get_snowflake_addr()
    return skynet.call(addr, "lua", "snowflake")
end

skynet.init(function()
    -- 初始化 snowflake master 服务
    skynet.uniqueservice "snowflake"

    -- 初始化 snowflake 服务地址列表
    service_list = {}
    local id_begin = tonumber(skynet.getenv "snowflake_begin") or 1
    local id_end = tonumber(skynet.getenv "snowflake_end") or 10
    assert(id_begin <= id_end, "snowflake_begin or snowflake_end error")

    local i = 0
    for id = id_begin, id_end do
        i = i + 1
        local service_name = string.format(".snowflake_%s", id)
        service_list[i] = skynet.localname(service_name)
    end
    service_max = i
end)

return M
