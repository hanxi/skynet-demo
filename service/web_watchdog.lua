local skynet = require "skynet"
local socket = require "skynet.socket"

local agent = {}
local CMD = {}
local protocol

function CMD.start(conf)
    protocol = conf.protocol or "http"

    local agent_cnt = conf.agent_cnt
	for i = 1, agent_cnt do
        agent[i] = skynet.newservice("web_agent", protocol)
    end

    local port = assert(conf.port)
    local balance = 1
    local id = socket.listen("0.0.0.0", port)
    skynet.error("Listen web port:", port)
    socket.start(id , function(id, addr)
        -- skynet.error(string.format("%s connected, pass it to agent :%08x", addr, agent[balance]))
        skynet.send(agent[balance], "lua", id)
        balance = balance + 1
        if balance > #agent then
            balance = 1
        end
    end)
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
		local f = assert(CMD[cmd])
		skynet.ret(skynet.pack(f(subcmd, ...)))
	end)
end)


