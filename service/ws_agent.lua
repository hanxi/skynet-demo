local cjson = require "cjson"
local dirtydb = require "dirtydb"
local role_db = require "role.role_db"
local role_mgr = require "role.role_mgr"
local skynet = require "skynet"
local socket = require "skynet.socket"

local WATCHDOG
local host
local send_request

local CMD = {}
local client_fd
local gate
local role_id

local RPC = {}
function RPC.cs_login(req)
    local acc = req.data.acc
    local role = role_mgr.find_create_role(acc)
    if not role then
        return {
            name = "sc_error",
            data = {
                req_name = "sc_login",
                msg = "find_create_role failed",
            },
        }
    end

    role_id = role:get_role_id()
    local sign_cnt = role:get_sign_cnt()
    return {
        name = "sc_login",
        data = {
            sign_cnt = sign_cnt,
        },
    }
end

function RPC.cs_sign(req)
    if role_id == nil then
        return {
            name = "sc_error",
            data = {
                req_name = "cs_sign",
                msg = "need login first",
            },
        }
    end
    local role = role_mgr.get_role(role_id)
    role:sign()
    local sign_cnt = role:get_sign_cnt()
    return {
        name = "sc_sign",
        data = {
            sign_cnt = sign_cnt,
        },
    }
end

function RPC.cs_logout(req)
    role_id = nil
end

skynet.register_protocol({
    name = "client",
    id = skynet.PTYPE_CLIENT,
    unpack = skynet.tostring,
    dispatch = function(fd, address, msg)
        assert(fd == client_fd) -- You can use fd to reply message
        skynet.ignoreret() -- session is fd, don't call skynet.ret
        --skynet.trace()
        local req = cjson.decode(msg)
        if req and RPC[req.name] then
            local ok, res = pcall(RPC[req.name], req)
            if ok then
                skynet.send(gate, "lua", "response", fd, cjson.encode(res))
            else
                error_res = {
                    name = "sc_error",
                    data = {
                        req_name = req.name,
                        msg = res,
                    },
                }
                skynet.send(gate, "lua", "response", fd, cjson.encode(error_res))
            end
        else
            -- echo simple
            skynet.send(gate, "lua", "response", fd, msg)
        end
        skynet.error(address, msg)
    end,
})

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

local function loop_timer()
    skynet.timeout(300, loop_timer) -- 设置3秒后再次调用自身
    -- 在这里写需要定时执行的代码
    skynet.error "loop_timer..."
    dirtydb.save_dirty()
end

skynet.start(function()
    role_db.init()
    dirtydb.need_schema(true)
    loop_timer()

    skynet.dispatch("lua", function(_, _, command, ...)
        --skynet.trace()
        local f = CMD[command]
        skynet.ret(skynet.pack(f(...)))
    end)
end)
