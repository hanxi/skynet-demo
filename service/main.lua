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
        print(">: " .. msg, ws_id)
        local resp, close_reason = websocket.read(ws_id)
        print("<: " .. (resp and resp or "[Close] " .. close_reason))
        if not resp then
            print("echo server close.")
            break
        end
        websocket.ping(ws_id)
        skynet.sleep(200)
    end
end

skynet.start(function()
    skynet.error("Server start")
    if not skynet.getenv "daemon" then
        skynet.newservice("console")
    end
    skynet.newservice("debug_console",8000)
    local ws_watchdog = skynet.newservice("ws_watchdog")
    local protocol = "ws"
    local ws_port = 8888
    skynet.call(ws_watchdog, "lua", "start", {
        port = ws_port,
        maxclient = max_client,
        nodelay = true,
        protocol = protocol,
    })
    skynet.error("websocket watchdog listen on", ws_port)

    local web_watchdog = skynet.newservice("web_watchdog")
    local web_port = 8889
    skynet.call(web_watchdog, "lua", "start", {
        port = web_port,
        agent_cnt = 1,
        protocol = "http",
    })
    skynet.error("web watchdog listen on", web_port)

    skynet.exit()
end)
