local config = require "config"
local log = require "log"
local mongo = require "skynet.db.mongo"
local util_table = require "util.table"
local json = require "json"
local snowflake = require "snowflake"

local M = {}

local db
local user_tbl
local test_tbl

-- 确保数组可以正常转为 bson
local bson_array_mt = {
    __len = function (a)
        return rawlen(a)
    end,
}

M.init_db = function ()
    local cfg = config.get_db_conf()
    local dbs = mongo.client(cfg)

    local db_name = config.get("db_name")
    log.info("connect to db:", db_name)
    db = dbs[db_name]

    user_tbl = db.user

    user_tbl:createIndex({{uid = 1}, unique = true})
    user_tbl:createIndex({{acc = 1}, unique = true})
    user_tbl:createIndex({{location = "2d"}})

    test_tbl = db.test
end

function M.test_insert(data)
    user_tbl:insert(data)
end

local function call_create_new_user(query)
    local uid = snowflake.snowflake()

    -- new user
    local user_data = {
        uid = uid,
    }
    util_table.merge(user_data, query)
    local ok, msg, ret = user_tbl:safe_insert(user_data)
    if (ok and ret and ret.n == 1) then
        log.info("new uid succ. uid:", uid, ",ret:", util_table.tostring(ret))
        return uid, user_data
    else
        return 0, "new user error:"..msg
    end
end

local function _call_load_user(query)
    local ret = user_tbl:findOne(query)
    if not ret then
        return call_create_new_user(query)
    end

    if not ret.uid then
        return 0, "cannot load user. query:"..util_table.tostring(query)
    end
    return ret.uid, ret
end

function M.call_load_user(query)
    local ok, uid, data = xpcall(_call_load_user, debug.traceback, query)
    if not ok then
        log.error("load user error. err:", uid)
        return 0, uid
    end
    return uid, data
end

-- 设置位置
function M.set_location(uid, longitude, latitude)
    local location = {longitude, latitude}
    setmetatable(location, bson_array_mt)
    local ret = user_tbl:findAndModify({query = {uid = uid}, update = {["$set"] = {location = location}}})
    local result = math.floor(ret.ok)
    if result ~= 1 then
        return false
    end
    return true
end

-- 获取附加的人
function M.get_near_player(longitude, latitude, limit)
    local pipeline = {
        {
            ["$geoNear"] = {
                near = setmetatable({ longitude, latitude }, bson_array_mt),
                distanceField = "location",
                maxDistance = 2000,
                query = {location = {["$exists"] = true}},
            },
        },
        {
            ["$project"] = {
                uid = 1,
                _id = 0,
            },
        },
        {
            ["$limit"] = limit or 10,
        },
    }
    setmetatable(pipeline, bson_array_mt)
    local ret = db:runCommand("aggregate", "user", "pipeline", pipeline, "cursor", {})
    log.debug("get_near_player:", util_table.tostring(ret))
    if ret then
        return ret.cursor.firstBatch
    end
end

--[[
-- 查询 2 千米范围内的玩家
db.user.aggregate([
{
    $geoNear: {
        near: [ -73.99279 , 40.719296 ],
        distanceField: "location",
        maxDistance: 2000,
        query: {location : {$exists: true}},
        includeLocs: "location",
        spherical: true,
    }
},
{
    $project: {
        uid:1,
        _id: 0
    }

},
{ $limit : 10 }
])
]]

return M
