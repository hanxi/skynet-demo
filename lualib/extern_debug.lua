local skynet = require "skynet"
local skynet_debug = require "skynet.debug"

local M = {}
local dbgcmd = {}

local old_snapshot
function dbgcmd.SNAPSHOT()
    local snapshot = require "snapshot"
    local construct_indentation = (require "snapshot_utils").construct_indentation
    collectgarbage "collect"
    local new_snapshot = snapshot()
    if not old_snapshot then
        old_snapshot = new_snapshot
        return skynet.ret(skynet.pack({}))
    end
    local diff = {}
    for k,v in pairs(new_snapshot) do
        if not old_snapshot[k] then
            diff[k] = v
        end
    end
    old_snapshot = new_snapshot
    local ret = construct_indentation(diff)
    skynet.ret(skynet.pack(ret))
end

function M.init()
    for k,v in pairs(dbgcmd) do
        skynet_debug.reg_debugcmd(k, v)
    end
end

return M
