local etcd = require "etcd"
local skynet = require "skynet"
local util_string = require "util.string"
local util_table = require "util.table"

local etcd_base_path = skynet.getenv "etcd_base_path"

-- test set and get
local function testsetget(etcd_cli)
    skynet.error "------------testsetget begin"
    res, err = etcd_cli:set("hello", { message = "world" })
    if not res then
        skynet.error(string.format("etcd set %s fail, err: %s", "hello", err))
        return
    end
    skynet.error(string.format("set key %s, revision: %s", "hello", util_table.tostring(res.body.header.revision)))

    res, err = etcd_cli:get "hello"
    if not res then
        skynet.error(string.format("etcd get %s fail, err: %s", "hello", err))
        return
    end
    skynet.error(string.format("key %s is %s", "hello", util_table.tostring(res.body.kvs[1].value)))

    res, err = etcd_cli:delete "hello"
    if not res then
        skynet.error(string.format("delete %s fail, err: %s", "hello", err))
        return
    end
    skynet.error(string.format("delete key %s, deleted: %s", "hello", util_table.tostring(res.body.deleted)))

    res, err = etcd_cli:get "hello"
    skynet.error(string.format("key %s is %s", "hello", util_table.tostring(res.body.kvs)))

    skynet.error "------------testsetget finished"
end

-- test setx
local function testsetx(etcd_cli)
    skynet.error "------------testsetx begin"
    res, err = etcd_cli:set("hello", { message = "world" })
    skynet.error(string.format("set key %s, revision: %s", "hello", util_table.tostring(res.body.header.revision)))

    res, err = etcd_cli:setx("hello", { message = "newWorld" })
    skynet.error(string.format("etcd setx %s, res: %s", "hello", util_table.tostring(res.body.header.revision)))

    res, err = etcd_cli:get "hello"
    skynet.error(
        string.format(
            "key %s is %s, create_revision: %s, mod_revision: %s",
            "hello",
            util_table.tostring(res.body.kvs[1].value),
            res.body.kvs[1].create_revision,
            res.body.kvs[1].mod_revision
        )
    )

    res, err = etcd_cli:setx("hello2", { message = "newhello" })
    skynet.error(string.format("etcd setx %s, res: %s", "hello2", util_table.tostring(res.body.responses)))

    res, err = etcd_cli:get "hello2"
    skynet.error(string.format("key %s is %s", "hello2", util_table.tostring(res.body.kvs)))

    res, err = etcd_cli:delete "hello"
    res, err = etcd_cli:delete "hello2"
    skynet.error "------------testsetx finished"
end

-- test setnx
local function testsetnx(etcd_cli)
    skynet.error "------------testsetnx begin"
    res, err = etcd_cli:set("hello", { message = "world" })
    res, err = etcd_cli:setnx("hello", { message = "newWorld" })
    res, err = etcd_cli:get "hello"
    skynet.error(string.format("key %s is %s", "hello", util_table.tostring(res.body.kvs[1].value)))

    res, err = etcd_cli:delete "hello"
    skynet.error "------------testsetnx finished"
end

-- test grant
local function testgrant(etcd_cli)
    skynet.error "------------testgrant begin"
    local res, err = etcd_cli:grant(2)
    if not res then
        skynet.error("testgrant fail: ", err)
        return
    end
    skynet.error(string.format("grant res: %s %s", res.body.ID, res.body.TTL))
    skynet.sleep(300)
    res, err = etcd_cli:grant(10, res.body.ID)
    skynet.error(string.format("grant %s res: %s %s", res.body.ID, res.body.ID, res.body.TTL))

    skynet.error "------------testgrant finished"
end

-- test revoke
local function testrevoke(etcd_cli)
    skynet.error "------------testrevoke begin"
    local res, err = etcd_cli:grant(10)
    local ID = res.body.ID
    res, err = etcd_cli:revoke(ID)
    skynet.error(string.format("revoke %s revision: %s", ID, util_table.tostring(res.body.header.revision)))
    skynet.error "------------testrevoke finished"
end

-- test keepalive and timetolive
local function testkeepalive(etcd_cli)
    skynet.error "------------testkeepalive begin"
    local res, err = etcd_cli:grant(10)
    local ID = res.body.ID
    res, err = etcd_cli:keepalive(ID)
    if not res then
        skynet.error("testkeepalive fail, err:", err)
        return
    end
    skynet.error(string.format("keepalive %s, res: %s", ID, util_table.tostring(res.body)))

    res, err = etcd_cli:timetolive(ID)
    skynet.error(string.format("timetolive %s, grantedTTL: %s, TTL: %s", ID, res.body.grantedTTL, res.body.TTL))
    skynet.sleep(1300)
    res, err = etcd_cli:timetolive(ID)
    skynet.error(util_table.tostring(res.body))
    skynet.error(string.format("timetolive %s, grantedTTL: %s, TTL: %s", ID, res.body.grantedTTL, res.body.TTL))
    skynet.error "------------testkeepalive finished"
end

-- test leases
local function testleases(etcd_cli)
    local res, err = etcd_cli:grant(10)
    skynet.error("grant lease", res.body.ID)
    res, err = etcd_cli:leases()
    if not res then
        skynet.error("testleases fail, err:", err)
        return
    end
    skynet.error(string.format("leases res: %s", util_table.tostring(res.body.leases)))
end

-- test etcd_cli
local function testreaddir(etcd_cli)
    local res, err = etcd_cli:set("hello", { message = "world" })
    res, err = etcd_cli:set("hello2", { message = "world2" })
    res, err = etcd_cli:set("hello3", { message = "world3" })
    res, err = etcd_cli:readdir(etcd_base_path)
    if not res then
        skynet.error("testreaddir fail, err: ", err)
        return
    end
    skynet.error(string.format("readdir res: %s", util_table.tostring(res.body.kvs)))
    etcd_cli:delete "hello"
    etcd_cli:delete "hello2"
    etcd_cli:delete "hello3"
end

-- test rmdir
local function testrmdir(etcd_cli)
    local res, err = etcd_cli:set("hello", { message = "world" })
    res, err = etcd_cli:set("hello2", { message = "world2" })
    res, err = etcd_cli:set("hello3", { message = "world3" })
    res, err = etcd_cli:readdir(etcd_base_path)
    skynet.error(string.format("rmdir#readdir res: %s", util_table.tostring(res.body.kvs)))
    res, err = etcd_cli:rmdir(etcd_base_path)
    if not res then
        skynet.error("testrmdir fail, err: ", err)
        return
    end

    res, err = etcd_cli:readdir(etcd_base_path)
    skynet.error(string.format("rmdir#readdir res: %s", util_table.tostring(res.body.kvs)))
end

-- test watch
local function testwatchdir(etcd_cli)
    local watch_fun <close>, err = etcd_cli:watchdir "/foo"
    if err then
        skynet.error "watchdir /foo failed."
        return
    end

    for ret, werr, stream in watch_fun do
        for _, ev in ipairs(ret.result.events or {}) do
            skynet.error(string.format("watchdir type:%s key:%s value:%s", ev.type, ev.kv.key, ev.kv.value))
        end
    end
end

local function testwatchone(etcd_cli)
    local watch_fun <close>, err = etcd_cli:watch "hello"
    if err then
        skynet.error "watch hello failed."
        return
    end

    for ret, werr, stream in watch_fun do
        for _, ev in ipairs(ret.result.events or {}) do
            skynet.error(string.format("watch type:%s key:%s value:%s", ev.type, ev.kv.key, ev.kv.value))
        end
    end
end

-- FIXME: 断线重试还有问题
local function testwatch(etcd_cli)
    skynet.fork(function()
        while true do
            local ok, err = xpcall(testwatchdir, debug.traceback, etcd_cli)
			if not ok then
				skynet.error("testwatch failed. err:", err)
			end
            skynet.sleep(100)
        end
    end)
    skynet.fork(function()
        while true do
            local ok, err = xpcall(testwatchone, debug.traceback, etcd_cli)
			if not ok then
				skynet.error("testwatch failed. err:", err)
			end
            skynet.sleep(100)
        end
    end)
end

skynet.start(function()
    local etcd_hosts = skynet.getenv "etcd_hosts"
    local etcd_user = skynet.getenv "etcd_user"
    local etcd_password = skynet.getenv "etcd_password"

    skynet.error("etcd_user: ", etcd_user)
    skynet.error("etcd_password: ", etcd_password)

    local opt = {
        http_host = util_string.split(etcd_hosts, ","),
        user = etcd_user,
        password = etcd_password,
        key_prefix = etcd_base_path,
    }

    local err
    etcd_cli, err = etcd.new(opt)
    if not etcd_cli then
        skynet.error("etcd client init wrong, ", err)
        return
    end

    testsetget(etcd_cli)
    testsetx(etcd_cli)
    testsetnx(etcd_cli)
    testgrant(etcd_cli)
    testrevoke(etcd_cli)
    testkeepalive(etcd_cli)
    testleases(etcd_cli)
    testreaddir(etcd_cli)
    testrmdir(etcd_cli)
    testwatch(etcd_cli)
end)
