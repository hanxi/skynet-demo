local skynet = require "skynet"
local service = require "service"
local log = require "log"

local function test1()
	local skynet = require "skynet"
	local service = require "service"
	local log = require "log"
	service.atexit(function ()
		log.info("in test1 exit2")
	end)
	service.atexit(function ()
		log.info("in test1 exit1")
	end)

	skynet.fork(function()
		skynet.sleep(100)
		service.exit()
	end)
end

local function test2()
	local skynet = require "skynet"
	local service = require "service"
	local log = require "log"

	service.atexit(function ()
		log.info("in test2 exit2")
	end)
	service.atexit(function ()
		log.info("in test2 exit1")
		skynet.sleep(600)
		log.info("out test2 exit1")
	end)

	skynet.fork(function()
		skynet.sleep(200)
		service.exit(0, 1, 5)
	end)
end

local function test3()
	local skynet = require "skynet"
	local service = require "service"
	local log = require "log"

	service.atexit(function ()
		log.info("in test3 exit2")
	end)
	service.atexit(function ()
		log.info("in test3 exit1")
	end)

	skynet.fork(function()
		skynet.sleep(300)
		service.exit(6, 5, 1)
	end)
end


skynet.start(function()
    local test1 = service.new("test1", test1)
    local test2 = service.new("test2", test2)
    local test3 = service.new("test3", test3)
end)
