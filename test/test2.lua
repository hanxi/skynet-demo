local protocol = "ws"
local skynet = require "skynet"
local websocket = require "http.websocket"
local url = string.format("%s://127.0.0.1:8888/test_websocket", protocol)

skynet.start(function()
    local ws_id = websocket.connect(url)
    while true do
        local msg = "hello world!"
        websocket.write(ws_id, msg)
        print(">: " .. msg, ws_id)
        local resp, close_reason = websocket.read(ws_id)
        print("<: " .. (resp and resp or "[Close] " .. close_reason))
        if not resp then
            print "echo server close."
            break
        end
        websocket.ping(ws_id)
        skynet.sleep(200)
    end
end)
