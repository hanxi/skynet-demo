local skynet = require "skynet"
require "skynet.manager"

local mode, agent_id = ...
local CMD = {}

if mode == "agent" then

agent_id = tonumber(agent_id)
local service_name = string.format(".snowflake_%s", agent_id)

local function parse_date(str_date)
    local pattern = "(%d+)-(%d+)-(%d+)"
    local y, m, d = str_date:match(pattern)
    return os.time({year = y, month = m, day = d})
end

-- 时间起点
local start_date = skynet.getenv("snowflake_start_date") or "2021-09-09"
local START_TIMESTAMP = parse_date(start_date)

-- 每一部分占用的位数
local TIME_BIT = 39       -- 时间占用的位数
local SEQUENCE_BIT = 12   -- 序列号占用的位数
local MACHINE_BIT = 12    -- 机器标识占用的位数

-- 每一部分的最大值
local MAX_SEQUENCE = 1 << SEQUENCE_BIT    -- 4096
local MAX_MACHINE_NUM = 1 << MACHINE_BIT  -- 4096
local MAX_TIME = 1 << TIME_BIT -- 549755813888 => (1 << 39) / (100 * 60 * 60 * 24 * 365) = 174 年

-- 每一部分向左的位移
local MACHINE_LEFT = SEQUENCE_BIT
local TIMESTAMP_LEFT = SEQUENCE_BIT + MACHINE_BIT

-- 上一次时间戳
local sequence = 0
local last_timestamp

-- 获取当前时间，单位 10ms
local function get_cur_timestamp()
    return math.floor(skynet.time() * 100)
end

-- 取下一个不同的时间
local function get_next_timestamp()
    local cur_timestamp = get_cur_timestamp()
    while cur_timestamp <= last_timestamp do
        cur_timestamp = get_cur_timestamp()
    end
    return cur_timestamp
end

function CMD.snowflake()
    local cur_timestamp = get_cur_timestamp()
    if cur_timestamp < last_timestamp then
        error("Clock moved backwards.  Refusing to generate id")
    end
    if cur_timestamp == last_timestamp then
        -- 相同 10ms 内，序列号自增
        sequence = (sequence + 1) & MAX_SEQUENCE
        -- 同一 10ms 的序列数已经达到最大
        if sequence == 0 then
            cur_timestamp = get_next_timestamp()
        end
    else
        -- 不同 10ms 内，序列号置为0
        sequence = 0
    end

    last_timestamp = cur_timestamp

    -- 10 ms 精度
    return (cur_timestamp - START_TIMESTAMP) << TIMESTAMP_LEFT  -- 时间戳部分
                | agent_id << MACHINE_LEFT                      -- 机器标识部分
                | sequence                                      -- 序列号部分
end

-- 每 3s 保存一次时间最后时间戳
local function auto_save_last_timestamp()
    local f = io.open(service_name, "w+")
    f:write(last_timestamp)
    f:close()

    skynet.timeout(300, auto_save_last_timestamp)
end

-- 启动前读取最后时间戳
skynet.init(function()
    local f = io.open(service_name)
    if f then
        local content = f:read("*a")
        f:close()
        last_timestamp = tonumber(content) or -1
    else
        last_timestamp = -1
    end
end)

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = assert(CMD[cmd])
        skynet.ret(skynet.pack(f(...)))
    end)
    auto_save_last_timestamp()
    skynet.register(service_name)
end)

else

skynet.start(function()
    local id_begin = tonumber(skynet.getenv("snowflake_begin")) or 1
    local id_end = tonumber(skynet.getenv("snowflake_end")) or 10
    assert(id_begin <= id_end, "snowflake_begin or snowflake_end error")

    for id = id_begin, id_end do
        skynet.newservice(SERVICE_NAME, "agent", id)
    end
    skynet.register(".snowflake")
end)

end
