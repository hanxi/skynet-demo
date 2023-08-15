local function mng_service()
	local skynet = require "skynet.manager"
	local log = require "log"

	local service_exit = {}
	local CMD = {}

	local function now()
		return math.floor(skynet.time())
	end

	function CMD.begin_exit(source, timeout)
		service_exit[source] = service_exit[source] or {}
		service_exit[source].begin_exit = now()
		service_exit[source].begin_exit_timeout = timeout
	end

	function CMD.end_exit(source, timeout)
		service_exit[source] = service_exit[source] or {}
		service_exit[source].end_exit = now()
		service_exit[source].end_exit_timeout = timeout
	end

	skynet.dispatch("lua", function(_, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(source, ...)))
        else
            log.error(string.format("Unknown cmd:%s, source:%s", cmd, source))
        end
    end)

	-- 超时强制退出检查
	local function check_exit_timeout()
		local now_time = now()
		for address, info in pairs(service_exit) do
			if info.begin_exit then
				local end_time = info.begin_exit + info.begin_exit_timeout
				if now_time > end_time then
					log.info("force kill in begin_exit. address:", address)
					skynet.kill(address)
				end
			end
			if info.end_exit then
				local end_time = info.end_exit + info.end_exit_timeout
				if now_time > end_time then
					log.info("force kill in end_exit. address:", address)
					skynet.kill(address)
				end
			end
		end
	end

	-- 5 秒心跳
    local HEARTBEAT_TIME = 5 * 100
	local function heartbeat_init()
		local function heartbeat()
			check_exit_timeout()
			skynet.timeout(HEARTBEAT_TIME, heartbeat)
		end
		heartbeat()
	end
	heartbeat_init()

	skynet.register_protocol {
		name = "client",
		id = skynet.PTYPE_CLIENT,
		unpack = function() end,
		dispatch = function(_, source)
			service_exit[source] = nil
			log.info("exit ok. source:", source)
		end
	}

	local c = require "skynet.core"
	c.command("MONITOR", skynet.address(skynet.self()))
	log.info("service monitor init ok.")
end

local skynet = require "skynet"
local service = require "skynet.service"
local log = require "log"

local function load_service(t, key)
    if key == "address" then
		local info = debug.getinfo(mng_service, "u")
        t.address = service.new("servicemng", mng_service)
        return t.address
    else
        return nil
    end
end

local servicemng = setmetatable ({} , {
    __index = load_service,
})


-- 退出时的处理函数
local exit_funcs = {}

-- 类似 C 语言的 atexit 函数，先注册的后执行
function service.atexit(f)
	table.insert(exit_funcs, f)
end

-- waittime 等待退出时间（单位秒） 默认 0 秒
-- timeout1 执行 atexit 的超时时间（单位秒） 默认 5 秒
-- timeout2 执行 skynet.exit 的超时时间（单位秒） 默认 5 秒
function service.exit(waittime, timeout1, timeout2)
	local DEFAULT_TIMEOUT = 5 -- 默认 5 秒超时
	waittime = waittime or 0
	timeout1 = timeout1 or DEFAULT_TIMEOUT
	timeout2 = timeout2 or DEFAULT_TIMEOUT
	skynet.call(servicemng.address, "lua", "begin_exit", timeout1)
	for i = #exit_funcs, 1, -1 do
		local f = exit_funcs[i]
		local ok, msg = xpcall(f, debug.traceback)
		if not ok then
			log.error("exit call failed. msg:", msg)
		end
	end
	skynet.call(servicemng.address, "lua", "end_exit", timeout2)
	skynet.sleep(waittime * 100)
	skynet.exit()
end

return service
