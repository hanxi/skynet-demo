local skynet = require "skynet"

local CMD = {}
local SOCKET = {}
local gate
local agent = {}
local protocol

function SOCKET.open(fd, addr)
    skynet.error("New client from : " .. addr)
    agent[fd] = skynet.newservice("ws_agent")
    skynet.call(agent[fd], "lua", "start", {
        gate = gate,
        client = fd,
        watchdog = skynet.self(),
        protocol = protocol,
        addr = addr,
    })
end

local function close_agent(fd)
    local a = agent[fd]
    agent[fd] = nil
    if a then
        skynet.call(gate, "lua", "kick", fd)
        -- disconnect never return
        skynet.send(a, "lua", "disconnect")
    end
end

function SOCKET.close(fd)
    print("socket close",fd)
    close_agent(fd)
end

function SOCKET.error(fd, msg)
    print("socket error",fd, msg)
    close_agent(fd)
end

function SOCKET.warning(fd, size)
    -- size K bytes havn't send out in fd
    print("socket warning", fd, size)
end

function SOCKET.data(fd, msg)
    print("socket data", fd, msg)
end

function CMD.start(conf)
    protocol = conf.protocol
    skynet.call(gate, "lua", "open" , conf)
end

function CMD.close(fd)
    close_agent(fd)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        if cmd == "socket" then
            local f = SOCKET[subcmd]
            f(...)
            -- socket api don't need return
        else
            local f = assert(CMD[cmd])
            skynet.ret(skynet.pack(f(subcmd, ...)))
        end
    end)

    gate = skynet.newservice("ws_gate")
end)

