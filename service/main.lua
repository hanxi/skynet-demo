local skynet = require "skynet"
local service = require "skynet.service"

local max_client = 64

local function simple_echo_client_service(protocol)
    local skynet = require "skynet"
    local websocket = require "http.websocket"
    local url = string.format("%s://127.0.0.1:8888/test_websocket", protocol)
    local ws_id = websocket.connect(url)
    while true do
        local msg = "hello world!"
        websocket.write(ws_id, msg)
        print(">: " .. msg)
        local resp, close_reason = websocket.read(ws_id)
        print("<: " .. (resp and resp or "[Close] " .. close_reason))
        if not resp then
            print("echo server close.")
            break
        end
        websocket.ping(ws_id)
        skynet.sleep(100)
    end
end

skynet.start(function()
    skynet.error("Server start")
    if not skynet.getenv "daemon" then
        skynet.newservice("console")
    end
    skynet.newservice("debug_console",8000)
    local watchdog = skynet.newservice("ws_watchdog")
    local protocol = "ws"
    skynet.call(watchdog, "lua", "start", {
        port = 8888,
        maxclient = max_client,
        nodelay = true,
        protocol = protocol,
    })
    skynet.error("websocket watchdog listen on", 8888)
    service.new("websocket_echo_client", simple_echo_client_service, protocol)
    skynet.exit()
end)
