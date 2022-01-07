local skynet = require "skynet"
require "skynet.manager"
local socket = require "skynet.socket"
local websocket = require "http.websocket"
local socketdriver = require "skynet.socketdriver"

local watchdog
local connection = {}   -- fd -> connection : { fd , client, agent , ip, mode }
local forwarding = {}   -- agent -> connection

local client_number = 0
local maxclient -- max client
local nodelay
local protocol

local master_name, slave_name = ...
master_name = master_name or ".ws_gate"

skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT,
}

local function launch_master()
    local CMD_MASTER = {}
    local slave = {}

    function CMD_MASTER.open(source, conf)
        local instance = conf.instance or 8
        assert(instance > 0)
        local balance = 1

        for i=1,instance do
            local _slave_name = string.format("%s-slave-%d", master_name, i)
            table.insert(slave, skynet.newservice(SERVICE_NAME, master_name, _slave_name))
        end

        conf.watchdog = conf.watchdog or source
        for i=1,instance do
            local s = slave[i]
            skynet.call(s, "lua", "open", conf)
        end

        local address = conf.address or "0.0.0.0"
        local port = assert(conf.port)
        protocol = conf.protocol or "ws"

        local fd = socket.listen(address, port)
        skynet.error(string.format("Listen websocket port:%s protocol:%s", port, protocol))
        socket.start(fd, function(fd, addr)
            skynet.error(string.format("accept client socket_fd: %s addr:%s", fd, addr))

            local s = slave[balance]
            balance = balance + 1
            if balance > #slave then
                balance = 1
            end
            local ok, err = skynet.call(s, "lua", "accept", fd, addr)
            if not ok then
                skynet.error(string.format("invalid client (fd = %d) error = %s", fd, err))
            end
        end)
    end

    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD_MASTER[cmd]
        if not f then
            skynet.error("ws gate master can't dispatch cmd ".. (cmd or nil))
            skynet.ret(skynet.pack({ok=false}))
            return
        end
        if session == 0 then
            f(source, ...)
        else
            skynet.ret(skynet.pack(f(source, ...)))
        end
    end)
end

local function launch_slave()

    local function unforward(c)
        if c.agent then
            forwarding[c.agent] = nil
            c.agent = nil
            c.client = nil
        end
    end

    local function close_fd(fd)
        local c = connection[fd]
        if c then
            unforward(c)
            connection[fd] = nil
            client_number = client_number - 1
        end
    end

    local handler = {}

    function handler.connect(fd)
        skynet.error("ws connect from: " .. tostring(fd))
        if client_number >= maxclient then
            socketdriver.close(fd)
            return
        end
        if nodelay then
            socketdriver.nodelay(fd)
        end

        client_number = client_number + 1
        local addr = websocket.addrinfo(fd)
        local c = {
            fd = fd,
            ip = addr,
        }
        connection[fd] = c

        skynet.send(watchdog, "lua", "socket", "open", fd, addr, skynet.self())
    end

    function handler.handshake(fd, header, url)
        local addr = websocket.addrinfo(fd)
        skynet.error("ws handshake from: " .. tostring(fd), "url", url, "addr:", addr)
        skynet.error("----header-----")
        for k,v in pairs(header) do
            skynet.error(k,v)
        end
        skynet.error("--------------")
    end

    function handler.message(fd, msg)
        skynet.error("ws ping from: " .. tostring(fd), msg.."\n")
        -- recv a package, forward it
        local c = connection[fd]
        local agent = c and c.agent
        -- msg is string
        if agent then
            skynet.redirect(agent, c.client, "client", fd, msg)
        else
            skynet.send(watchdog, "lua", "socket", "data", fd, msg)
        end
    end

    function handler.ping(fd)
        skynet.error("ws ping from: " .. tostring(fd) .. "\n")
    end

    function handler.pong(fd)
        skynet.error("ws pong from: " .. tostring(fd))
    end

    function handler.close(fd, code, reason)
        skynet.error("ws close from: " .. tostring(fd), code, reason)
        close_fd(fd)
        skynet.send(watchdog, "lua", "socket", "close", fd)
    end

    function handler.error(fd)
        skynet.error("ws error from: " .. tostring(fd))
        close_fd(fd)
        skynet.send(watchdog, "lua", "socket", "error", fd, msg)
    end

    function handler.warning(fd, size)
        skynet.send(watchdog, "lua", "socket", "warning", fd, size)
    end

    local CMD_SLAVE = {}
    function CMD_SLAVE.forward(source, fd, client, address)
        local c = assert(connection[fd])
        unforward(c)
        c.client = client or 0
        c.agent = address or source
        forwarding[c.agent] = c
    end

    function CMD_SLAVE.response(source, fd, msg)
        skynet.error("ws response: " .. tostring(fd), msg.."\n")
        -- forward msg
        websocket.write(fd, msg)
    end

    function CMD_SLAVE.kick(source, fd)
        websocket.close(fd)
    end

    function CMD_SLAVE.accept(source, fd, addr)
        return websocket.accept(fd, handler, protocol, addr)
    end

    function CMD_SLAVE.open(source, conf)
        maxclient = conf.maxclient or 1024
        nodelay = conf.nodelay
        protocol = conf.protocol or "ws"
        watchdog = conf.watchdog
        skynet.error("open", watchdog, source)
    end

    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD_SLAVE[cmd]
        if not f then
            skynet.error("ws gate slave can't dispatch cmd ".. (cmd or nil))
            skynet.ret(skynet.pack({ok=false}))
            return
        end
        if session == 0 then
            f(source, ...)
        else
            skynet.ret(skynet.pack(f(source, ...)))
        end
    end)
end

skynet.start(function()
    if slave_name then
        skynet.error("start ws_gate slave:", slave_name)
        skynet.register(slave_name)
        launch_slave()
    else
        skynet.error("start ws_gate master:", master_name)
        skynet.register(master_name)
        launch_master()
    end
end)

