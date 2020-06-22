local skynet = require "skynet"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"

local web_router = require "web_router"
local router = require 'router'

local r = router.new()
web_router(r)

local protocol = ...
protocol = protocol or "http"

local function response(id, write, ...)
    local ok, err = httpd.write_response(write, ...)
    if not ok then
        -- if err == sockethelper.socket_error , that means socket closed.
        skynet.error(string.format("fd = %d, %s", id, err))
    end
    skynet.error("fd=", id)
end

local function handle_request(id, url, method, header, body, interface)
    -- 通用的
    r:match({
        GET = {
            ["/hello"]       = function(params) return "someone said hello" end,
            ["/hello/:name"] = function(params) return "hello, " .. params.name end
        },
        POST = {
            ["/app/:id/comments"] = function(params)
                return "comment " .. params.comment .. " created on app " .. params.id
            end
        }
    })

    local path, query_str = urllib.parse(url)
    local query
    if query_str then
        query = urllib.parse_query(query_str)
    else
        query = {}
    end

    local ok, msg, code = r:execute(method, path, query, {header = header, body = body})
    if ok then
        skynet.error(msg, code)
        response(id, interface.write, code or 200, msg)
    else
        response(id, interface.write, 404, "404 Not found")
    end
end

local SSLCTX_SERVER = nil
local function gen_interface(protocol, fd)
    if protocol == "http" then
        return {
            init = nil,
            close = nil,
            read = sockethelper.readfunc(fd),
            write = sockethelper.writefunc(fd),
        }
    elseif protocol == "https" then
        local tls = require "http.tlshelper"
        if not SSLCTX_SERVER then
            SSLCTX_SERVER = tls.newctx()
            -- gen cert and key
            -- openssl req -x509 -newkey rsa:2048 -days 3650 -nodes -keyout server-key.pem -out server-cert.pem
            local certfile = skynet.getenv("certfile") or "./server-cert.pem"
            local keyfile = skynet.getenv("keyfile") or "./server-key.pem"
            print(certfile, keyfile)
            SSLCTX_SERVER:set_cert(certfile, keyfile)
        end
        local tls_ctx = tls.newtls("server", SSLCTX_SERVER)
        return {
            init = tls.init_responsefunc(fd, tls_ctx),
            close = tls.closefunc(tls_ctx),
            read = tls.readfunc(fd, tls_ctx),
            write = tls.writefunc(fd, tls_ctx),
        }
    else
        error(string.format("Invalid protocol: %s", protocol))
    end
end

local function close(id, interface)
    socket.close(id)
    if interface.close then
        interface.close()
    end
end

skynet.start(function()
    skynet.dispatch("lua", function (_,_,id)
        socket.start(id)
        skynet.error("start id:", id)
        local interface = gen_interface(protocol, id)
        if interface.init then
            interface.init()
        end
        -- limit request body size to 8192 (you can pass nil to unlimit)
        local code, url, method, header, body = httpd.read_request(interface.read, 8192)
        skynet.error(url)
        if not code then
            if url == sockethelper.socket_error then
                skynet.error("socket closed")
            else
                skynet.error(url)
            end
            close(id, interface)
            return
        end

        if code ~= 200 then
            response(id, interface.write, code)
            close(id, interface)
            return
        end

        handle_request(id, url, method, header, body, interface)
        close(id, interface)
    end)
end)

