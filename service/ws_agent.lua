local skynet = require "skynet"
local socket = require "skynet.socket"

local WATCHDOG
local host
local send_request

local CMD = {}
local client_fd
local gate

skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT,
    unpack = skynet.tostring,
    dispatch = function(fd, address, msg)
        assert(fd == client_fd) -- You can use fd to reply message
        skynet.ignoreret()  -- session is fd, don't call skynet.ret
        --skynet.trace()
        -- echo simple
        skynet.send(gate, "lua", "response", fd, msg)
        skynet.error(address, msg)
    end
}

function CMD.start(conf)
    local fd = conf.client
    gate = conf.gate
    WATCHDOG = conf.watchdog
    client_fd = fd
    skynet.call(gate, "lua", "forward", fd)
end

function CMD.disconnect()
    -- todo: do something before exit
    skynet.exit()
end

skynet.start(function()
    skynet.dispatch("lua", function(_,_, command, ...)
        --skynet.trace()
        local f = CMD[command]
        skynet.ret(skynet.pack(f(...)))
    end)
end)
