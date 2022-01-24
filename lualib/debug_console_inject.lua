local source = [[
local function getupvaluetable(u, func, unique)
    unique = unique or {}
	local i = 1
	while true do
		local name, value = debug.getupvalue(func, i)
		if name == nil then
			return
		end
		local t = type(value)
		if t == "table" then
			u[name] = value
		elseif t == "function" then
			if not unique[value] then
				unique[value] = true
				getupvaluetable(u, value, unique)
			end
		end
		i=i+1
	end
end

local skynet = require "skynet"
local TIMEOUT = 300 -- 3 sec
local function timeout(ti)
	if ti then
		ti = tonumber(ti)
		if ti <= 0 then
			ti = nil
		end
	else
		ti = TIMEOUT
	end
	return ti
end
local function stat(ti)
	local statlist = skynet.call(".launcher", "lua", "STAT", timeout(ti))
	local memlist = skynet.call(".launcher", "lua", "MEM", timeout(ti))
    local memkv = {}
    for k,v in pairs(memlist) do
        memkv[k] = v
    end
    for k,v in pairs(statlist) do
        v.xmem=memkv[k]
    end
    return statlist
end

local socket = require "skynet.socket"
local u1 = {}
getupvaluetable(u1, _P.socket.socket_message[1])
for k,v in pairs(u1.socket_pool) do
    if v.callback then
        local u2 = {}
        getupvaluetable(u2, v.callback)
        for kk,vv in pairs(u2) do
            if u2.COMMAND then
                u2.COMMAND.stat = stat
            end
        end
    end
end
]]

local skynet = require "skynet"
return function(address)
    skynet.call(address, "debug", "RUN", source)
end

