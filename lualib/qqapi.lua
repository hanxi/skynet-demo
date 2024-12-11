local config = require "config"
local httpc = require "http.httpc"
local json = require "json"
local log = require "log"
local skynet = require "skynet"

local M = {}

local access_token
local expires_in = 0
function M.refresh_access_token()
    local now = math.floor(skynet.time())
    if access_token then
        if now < expires_in then
            return
        end
    end

    local host = "https://api.q.qq.com"
    local url = string.format(
        "/api/getToken?grant_type=client_credential&appid=%s&secret=%s",
        config.get "qq_appid",
        config.get "qq_secret"
    )
    local status, ret = httpc.request("GET", host, url, {})
    log.info("refresh_access_token. url:", url, ",ret:", ret)
    if status == 200 then
        ret = json.decode(ret)
        if ret.errcode == 0 then
            access_token = ret.access_token
            expires_in = now + ret.expires_in
            log.info("refresh_access_token ok. access_token:", access_token)
        end
    end
end

function M.check_msg(msg)
    M.refresh_access_token()
    local host = "https://api.q.qq.com"
    local header = {
        ["content-type"] = "application/json",
    }
    local url = string.format("/api/json/security/MsgSecCheck?access_token=%s", access_token)
    local data = {
        appid = appid,
        content = msg,
    }
    local status, ret = httpc.request("POST", host, url, {}, header, json.encode(data))
    log.debug("check_msg. msg:", msg, ", status:", status, ", url:", url, ", ret:", ret)

    if status ~= 200 then
        return false
    end

    ret = json.decode(ret)
    if ret.errCode ~= 0 then
        return false
    end
    return true
end

return M
