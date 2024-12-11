local config = require "config"
local db = require "db"
local guid = require "guid"
local skynet = require "skynet"
local util_string = require "util.string"

local function test_db()
    local query = {
        acc = "test2",
    }
    local uid, user_data = db.call_load_user(query)
    assert(uid > 0)

    if user_data._id then
        skynet.error("uid:", uid, "user_data._id:", util_string.tohex(user_data._id))
    end

    local data = {
        hello = "world",
    }
    db.test_insert(data)
    skynet.error("data._id:", util_string.tohex(data._id))

    local longitude, latitude = -73.99279, 40.719296
    local ret = db.set_location(uid, longitude, latitude)
    assert(ret)
    db.get_near_player(longitude, latitude)
end

skynet.start(function()
    local cfg = config.get_db_conf()
    cfg.dbname = config.get "guid_db_name"
    cfg.tblname = config.get "guid_tbl_name"
    cfg.idtypes = config.get_tbl "guid_idtypes"
    guid.init(cfg)
    db.init_db()
    test_db()
end)
