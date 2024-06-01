local M = {}

local config = require "config"
local log = require "log"
local mongo = require "skynet.db.mongo"
local util_table = require "util.table"
local util_time = require "util.time"
local snowflake = require "snowflake"

-- role_coll 角色表
local role_coll

local function _get_collection(db_name, coll_name)
    local db_conf = config.get_tbl("db_conf_"..db_name)
    local dbs = mongo.client(db_conf)
    local db = dbs[db_name]
	local coll = db[coll_name]
    log.info("connect to db:", db_name, ", coll:", coll_name)
	return coll
end

-- 初始化不能并发
function M.init()
	role_coll = _get_collection("game", "role")
    role_coll:createIndex({{acc = 1}, unique = true})
    role_coll:createIndex({{uid = 1}, unique = true})
end

local function _create_role(acc, uid)
    local obj = {
		acc = acc,
		uid = uid,
		timestamp = util_time.now(),
    }
	local ok, err, r = role_coll:safe_insert(obj)
    if not ok then
		log.error("_create_role failed. acc:", acc, ", uid:", uid, ", err:", err)
        return false, err, r
    end
	log.info("_create_role ok. acc:", acc, ", uid:", uid)
	return obj
end

local function _get_role_by_acc(acc)
    assert(acc)
    log.debug("get_role acc:", acc)
    return role_coll:findOne({acc=acc}, {_id = false})
end

function M.load_role(acc)
	local role = _get_role_by_acc(acc)
	if not role then
		local uid = snowflake.snowflake()
		return _create_role(acc, uid)
	end
    return role
end

function M.load_role_by_uid(uid)
    assert(uid)
    log.debug("load_role_by_uid uid:", uid)
	return role_coll:findOne({uid=uid}, {_id = false})
end

function M.save_update(query, update)
	log.debug("save_update. query:", util_table.tostring(query), ", update:", util_table.tostring(update))
    local ret = role_coll:findAndModify({query = query, update = update})
	local result = math.floor(ret.ok)
    if result ~= 1 then
		log.error("save_update failed. uid:", query.uid, ", update:", util_table.tostring(update), ",ret:", util_table.tostring(ret))
        return false
    end
    return true
end

function M.get_save_cb(uid)
	return function(update)
		M.save_update({uid=uid}, update)
	end
end

return M
