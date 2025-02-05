local cjson = require "cjson.safe"
local crypt = require "skynet.crypt"
local httpc = require "http.httpc"
local skynet = require "skynet"

local setmetatable = setmetatable
local random = math.random
local string_match = string.match
local string_char = string.char
local string_byte = string.byte
local string_sub = string.sub
local table_insert = table.insert
local decode_json = cjson.decode
local encode_json = cjson.encode
local now = os.time
local encode_base64 = crypt.base64encode
local decode_base64 = crypt.base64decode
local log_info = skynet.error

local INIT_COUNT_RESIZE = 2e8
local API_PREFIX = "/v3"
local URL_AUTHENTICATE = API_PREFIX .. "/auth/authenticate"
local URL_PUT = API_PREFIX .. "/kv/put"
local URL_RANGE = API_PREFIX .. "/kv/range"
local URL_DELETERANGE = API_PREFIX .. "/kv/deleterange"
local URL_TXN = API_PREFIX .. "/kv/txn"
local URL_GRANT = API_PREFIX .. "/lease/grant"
local URL_REVOKE = API_PREFIX .. "/kv/lease/revoke"
local URL_KEEPALIVE = API_PREFIX .. "/lease/keepalive"
local URL_TIMETOLIVE = API_PREFIX .. "/kv/lease/timetolive"
local URL_LEASES = API_PREFIX .. "/lease/leases"
local URL_WATCH = API_PREFIX .. "/watch"

local _M = {}
local mt = { __index = _M }

local function clear_tab(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

local function table_exist_keys(t)
    return next(t)
end

local function tab_clone(obj)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end

        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end

        return new_table
    end

    return _copy(obj)
end

local function verify_key(key)
    if not key or #key == 0 then
        return false, "key should not be empty"
    end

    return true, nil
end

local function get_real_key(prefix, key)
    return (type(prefix) == "string" and prefix or "") .. key
end

-- define local refresh function variable
local refresh_jwt_token

local function _request_pre(self, uri, opts, timeout, ignore_auth)
    local body
    if opts and opts.body and table_exist_keys(opts.body) then
        body = encode_json(opts.body)
    end

    if opts and opts.query and table_exist_keys(opts.query) then
        uri = uri .. "?" .. encode_args(opts.query)
    end

    local headers = {}
    local keepalive = true
    if self.is_auth then
        if not ignore_auth then
            -- authentication request not need auth request
            local _, err = refresh_jwt_token(self, timeout)
            if err then
                return nil, err
            end

            headers.Authorization = self.jwt_token
        else
            keepalive = false -- jwt_token not keepalive
        end
    end
    -- TODO: keepalive not support in skynet
    return { uri = uri, headers = headers, body = body, keepalive = keepalive }
end

local function _request_uri(self, host, method, uri, opts, timeout, ignore_auth)
    log_info("_request_uri uri: ", uri, ", timeout: ", timeout)

    local ret, err = _request_pre(self, uri, opts, timeout, ignore_auth)
    if err then
        return nil, err
    end

    local recvheader = {}
    local status, body = httpc.request(method, host, ret.uri, recvheader, ret.headers, ret.body)
    if status >= 500 then
        return nil, "invalid response code: " .. status
    end

    if status == 401 then
        return nil, "insufficient credentials code: " .. status
    end

    if type(body) ~= "string" then
        return { status = status, body = body }
    end

    return { status = status, headers = recvheader, body = decode_json(body) }
end

local function _request_uri_stream(self, host, method, uri, opts, timeout, ignore_auth)
    log_info("_request_uri_stream uri: ", uri, ", timeout: ", timeout)

    local ret, err = _request_pre(self, uri, opts, timeout, ignore_auth)
    if err then
        return nil, err
    end

    local recvheader = {}

    return httpc.request_stream(method, host, ret.uri, recvheader, ret.headers, ret.body)
end

local function ring_balancer(self)
    local endpoints = self.endpoints
    local endpoints_len = #endpoints

    self.init_count = (self.init_count or random(100)) + 1
    local pos = self.init_count % endpoints_len + 1
    if self.init_count >= INIT_COUNT_RESIZE then
        self.init_count = 0
    end

    return endpoints[pos]
end

local fail_timeout = 10 -- 10 sec
local fail_expired_time = {} -- map[http_host]time

local function health_check(http_host)
    if type(http_host) ~= "string" then
        return false, "etcd http_host invalid"
    end
    local host_fail_expired_time = fail_expired_time[http_host]
    if host_fail_expired_time and host_fail_expired_time >= now() then
        return false, "http_host: " .. http_host .. " is unhealthy"
    end
    return true
end

local function report_failure(http_host)
    log_info("report_failure", http_host)
    fail_expired_time[http_host] = now() + fail_timeout
end

local function choose_endpoint(self)
    if not self.is_cluster then
        return self.endpoints[1]
    end

    for _ = 1, #self.endpoints do
        local endpoint = ring_balancer(self)
        if health_check(endpoint.http_host) then
            return endpoint
        end
    end

    return self.endpoints[1]
end

local function _post(self, uri, body, timeout, ignore_auth)
    local endpoint, err = choose_endpoint(self)
    if not endpoint then
        return nil, err
    end

    local ok, err = xpcall(
        _request_uri,
        debug.traceback,
        self,
        endpoint.http_host,
        "POST",
        uri,
        { body = body },
        timeout,
        ignore_auth
    )
    if not ok then
        report_failure(endpoint.http_host)
        log_info("_post failed.", err)
        return nil, err
    else
        return err
    end
end

local function _post_stream(self, uri, body, timeout)
    local endpoint, err = choose_endpoint(self)
    if not endpoint then
        return nil, err
    end
    local ok, err =
        xpcall(_request_uri_stream, debug.traceback, self, endpoint.http_host, "POST", uri, { body = body }, timeout)
    if not ok then
        report_failure(endpoint.http_host)
        return nil, err
    end
    return { stream = err, endpoint = endpoint }
end

local function serialize_and_encode_base64(data)
    local err
    data, err = encode_json(data)
    if not data then
        return nil, err
    end

    return encode_base64(data)
end

function _M.new(opts)
    local timeout = opts.timeout or 5
    local ttl = opts.ttl or -1
    local http_host = opts.http_host
    local user = opts.user
    local password = opts.password
    local key_prefix = opts.key_prefix or ""

    local endpoints = {}
    local http_hosts
    if type(http_host) == "string" then
        http_hosts = { http_host }
    else
        http_hosts = http_host
    end

    for _, host in ipairs(http_hosts) do
        local m, err = string_match(host, [[[a-zA-z]+://[^\s]*]])
        if not m then
            return nil, "inalid http_host: " .. host .. ", err: " .. (err or "not matched")
        end

        table_insert(endpoints, {
            http_host = host,
            scheme = m[1],
            host = m[2] or "127.0.0.1",
            port = m[3] or "2379",
        })
    end

    return setmetatable({
        last_auth_time = now(), -- save last Authentication time
        last_refresh_jwt_err = nil,
        jwt_token = nil, -- last Authentication token
        is_auth = not not (user and password),
        user = user,
        password = password,
        timeout = timeout,
        ttl = ttl,
        is_cluster = #endpoints > 1,
        endpoints = endpoints,
        key_prefix = key_prefix,
    }, mt)
end

-- return refresh_is_ok, error
function refresh_jwt_token(self, timeout)
    -- token exist and not expire
    -- default is 5min, we use 3min plus random seconds to smooth the refresh across workers
    -- https://github.com/etcd-io/etcd/issues/8287
    if self.jwt_token and now() - self.last_auth_time < 60 * 3 + random(0, 60) then
        return true, nil
    end

    if self.requesting_token then
        skynet.sleep(timeout)
        if self.jwt_token and now() - self.last_auth_time < 60 * 3 + random(0, 60) then
            return true, nil
        end

        if self.last_refresh_jwt_err then
            log_info("v3 refresh jwt last err: ", self.last_refresh_jwt_err)
            return nil, self.last_refresh_jwt_err
        end

        -- something unexpected happened, try again
        log_info("v3 try auth after waiting, timeout: ", timeout)
    end

    self.last_refresh_jwt_err = nil
    self.requesting_token = true

    local body = {
        name = self.user,
        password = self.password,
    }

    local res, err = _post(self, URL_AUTHENTICATE, body, timeout, true)
    self.requesting_token = false

    if err then
        self.last_refresh_jwt_err = err
        return nil, err
    end

    if not res or not res.body or not res.body.token then
        err = "authenticate refresh token fail"
        self.last_refresh_jwt_err = err
        return nil, err
    end

    self.jwt_token = res.body.token
    self.last_auth_time = now()

    return true, nil
end

local function set(self, key, val, attr)
    local _, err = verify_key(key)
    if err then
        return nil, err
    end

    key = encode_base64(key)
    val, err = serialize_and_encode_base64(val)
    if not val then
        return nil, err
    end

    attr = attr or {}

    local lease
    if attr.lease then
        lease = attr.lease
    end

    local prev_kv
    if attr.prev_kv then
        prev_kv = true
    end

    local ignore_value
    if attr.ignore_value then
        ignore_value = true
    end

    local ignore_lease
    if attr.ignore_lease then
        ignore_lease = true
    end

    local body = {
        value = val,
        key = key,
        lease = lease,
        prev_kv = prev_kv,
        ignore_value = ignore_value,
        ignore_lease = ignore_lease,
    }

    local res
    res, err = _post(self, URL_PUT, body, self.timeout)
    if err then
        return nil, err
    end

    if res.status < 300 then
        log_info("v3 set body: ", encode_json(res.body))
    end

    return res, nil
end

local function get(self, key, attr)
    local _, err = verify_key(key)
    if err then
        return nil, err
    end

    attr = attr or {}

    local range_end
    if attr.range_end then
        range_end = encode_base64(attr.range_end)
    end

    local limit
    if attr.limit then
        limit = attr.limit
    end

    local revision
    if attr.revision then
        revision = attr.revision
    end

    local sort_order
    if attr.sort_order then
        sort_order = attr.sort_order
    end

    local sort_target
    if attr.sort_target then
        sort_target = attr.sort_target
    end

    local serializable
    if attr.serializable then
        serializable = true
    end

    local keys_only
    if attr.keys_only then
        keys_only = true
    end

    local count_only
    if attr.count_only then
        count_only = true
    end

    local min_mod_revision
    if attr.min_mod_revision then
        min_mod_revision = attr.min_mod_revision
    end

    local max_mod_revision
    if attr.max_mod_revision then
        max_mod_revision = attr.max_mod_revision
    end

    local min_create_revision
    if attr.min_create_revision then
        min_create_revision = attr.min_create_revision
    end

    local max_create_revision
    if attr.max_create_revision then
        max_create_revision = attr.max_create_revision
    end

    key = encode_base64(key)

    local body = {
        key = key,
        range_end = range_end,
        limit = limit,
        revision = revision,
        sort_order = sort_order,
        sort_target = sort_target,
        serializable = serializable,
        keys_only = keys_only,
        count_only = count_only,
        min_mod_revision = min_mod_revision,
        max_mod_revision = max_mod_revision,
        min_create_revision = min_create_revision,
        max_create_revision = max_create_revision,
    }

    local res
    res, err = _post(self, URL_RANGE, body, attr and attr.timeout or self.timeout)
    if res and res.status == 200 then
        if res.body.kvs and next(res.body.kvs) then
            for _, kv in ipairs(res.body.kvs) do
                kv.key = decode_base64(kv.key)
                kv.value = decode_base64(kv.value or "")
                kv.value = decode_json(kv.value)
            end
        end
    end

    return res, err
end

local function delete(self, key, attr)
    local _, err = verify_key(key)
    if err then
        return nil, err
    end

    attr = attr or {}

    local range_end
    if attr.range_end then
        range_end = encode_base64(attr.range_end)
    end

    local prev_kv
    if attr.prev_kv then
        prev_kv = true
    end

    key = encode_base64(key)

    local body = {
        key = key,
        range_end = range_end,
        prev_kv = prev_kv,
    }

    return _post(self, URL_DELETERANGE, body, self.timeout)
end

local function txn(self, opts_arg, compare, success, failure)
    if #compare < 1 then
        return nil, "compare couldn't be empty"
    end

    if (success == nil or #success < 1) and (failure == nil or #failure < 1) then
        return nil, "success and failure couldn't be empty at the same time"
    end

    local timeout = opts_arg and opts_arg.timeout
    local body = {
        compare = compare,
        success = success,
        failure = failure,
    }

    return _post(self, URL_TXN, body, timeout or self.time)
end

local function get_range_end(key)
    if #key == 0 then
        return string_char(0)
    end

    local last = string_sub(key, -1)
    key = string_sub(key, 1, #key - 1)

    local ascii = string_byte(last) + 1
    local str = string_char(ascii)

    return key .. str
end

do
    local attr = {}
    function _M.get(self, key, opts)
        if type(key) ~= "string" then
            return nil, "key must be string"
        end

        key = get_real_key(self.key_prefix, key)

        clear_tab(attr)
        attr.timeout = opts and opts.timeout
        attr.revision = opts and opts.revision

        return get(self, key, attr)
    end

    function _M.readdir(self, key, opts)
        clear_tab(attr)

        key = get_real_key(self.key_prefix, key)

        attr.range_end = get_range_end(key)
        attr.revision = opts and opts.revision
        attr.timeout = opts and opts.timeout
        attr.limit = opts and opts.limit
        attr.sort_order = opts and opts.sort_order
        attr.sort_target = opts and opts.sort_target
        attr.keys_only = opts and opts.keys_only
        attr.count_only = opts and opts.count_only

        return get(self, key, attr)
    end
end -- do

do
    local attr = {}
    function _M.set(self, key, val, opts)
        clear_tab(attr)

        key = get_real_key(self.key_prefix, key)

        attr.timeout = opts and opts.timeout
        attr.lease = opts and opts.lease
        attr.prev_kv = opts and opts.prev_kv
        attr.ignore_value = opts and opts.ignore_value
        attr.ignore_lease = opts and opts.ignore_lease

        return set(self, key, val, attr)
    end

    -- set key-val if key does not exists (atomic create)
    local compare = {}
    local success = {}
    local failure = {}
    function _M.setnx(self, key, val, opts)
        clear_tab(compare)

        key = get_real_key(self.key_prefix, key)

        compare[1] = {}
        compare[1].target = "CREATE"
        compare[1].key = encode_base64(key)
        compare[1].createRevision = 0

        clear_tab(success)
        success[1] = {}
        success[1].requestPut = {}
        success[1].requestPut.key = encode_base64(key)

        local err
        val, err = serialize_and_encode_base64(val)
        if not val then
            return nil, "failed to encode val: " .. err
        end
        success[1].requestPut.value = val

        return txn(self, opts, compare, success, nil)
    end

    -- set key-val and ttl if key is exists (update)
    function _M.setx(self, key, val, opts)
        clear_tab(compare)

        key = get_real_key(self.key_prefix, key)

        compare[1] = {}
        compare[1].target = "CREATE"
        compare[1].key = encode_base64(key)
        compare[1].createRevision = 0

        clear_tab(failure)
        failure[1] = {}
        failure[1].requestPut = {}
        failure[1].requestPut.key = encode_base64(key)

        local err
        val, err = serialize_and_encode_base64(val)
        if not val then
            return nil, "failed to encode val: " .. err
        end
        failure[1].requestPut.value = val

        return txn(self, opts, compare, nil, failure)
    end
end -- do

function _M.txn(self, compare, success, failure, opts)
    local err

    if compare then
        local new_rules = tab_clone(compare)
        for i, rule in ipairs(compare) do
            rule = tab_clone(rule)
            rule.key = encode_base64(get_real_key(self.key_prefix, rule.key))
            if rule.value then
                rule.value, err = serialize_and_encode_base64(rule.value)
                if not rule.value then
                    return nil, "failed to encode value: " .. err
                end
            end

            new_rules[i] = rule
        end
        compare = new_rules
    end

    if success then
        local new_rules = tab_clone(success)
        for i, rule in ipairs(success) do
            rule = tab_clone(rule)
            if rule.requestPut then
                local requestPut = tab_clone(rule.requestPut)
                requestPut.key = encode_base64(get_real_key(self.key_prefix, requestPut.key))
                requestPut.value, err = serialize_and_encode_base64(requestPut.value)
                if not requestPut.value then
                    return nil, "failed to encode value: " .. err
                end

                rule.requestPut = requestPut
            end
            new_rules[i] = rule
        end
        success = new_rules
    end

    return txn(self, opts, compare, success, failure)
end

function _M.grant(self, ttl, id)
    if ttl == nil then
        return nil, "lease grant command needs TTL argument"
    end

    if type(ttl) ~= "number" then
        return nil, "ttl must be integer"
    end

    id = id or 0
    local body = {
        TTL = ttl,
        ID = id,
    }

    return _post(self, URL_GRANT, body)
end

function _M.revoke(self, id)
    if id == nil then
        return nil, "lease revoke command needs ID argument"
    end

    local body = {
        ID = id,
    }

    return _post(self, URL_REVOKE, body)
end

function _M.keepalive(self, id)
    if id == nil then
        return nil, "lease keepalive command needs ID argument"
    end

    local body = {
        ID = id,
    }

    return _post(self, URL_KEEPALIVE, opts)
end

function _M.timetolive(self, id, keys)
    if id == nil then
        return nil, "lease timetolive command needs ID argument"
    end

    keys = keys or false
    local body = {
        ID = id,
        keys = keys,
    }

    local res
    res, err = _post(self, URL_TIMETOLIVE, body)
    if res and res.status == 200 then
        if res.body.keys and next(res.body.keys) then
            for i, key in ipairs(res.body.keys) do
                res.body.keys[i] = decode_base64(key)
            end
        end
    end

    return res, err
end

function _M.leases(self)
    return _post(self, URL_LEASES)
end

do
    local attr = {}
    function _M.delete(self, key, opts)
        clear_tab(attr)

        key = get_real_key(self.key_prefix, key)

        attr.timeout = opts and opts.timeout
        attr.prev_kv = opts and opts.prev_kv

        return delete(self, key, attr)
    end

    function _M.rmdir(self, key, opts)
        clear_tab(attr)

        key = get_real_key(self.key_prefix, key)

        attr.range_end = get_range_end(key)
        attr.timeout = opts and opts.timeout
        attr.prev_kv = opts and opts.prev_kv

        return delete(self, key, attr)
    end
end -- do

local watch_mt = {
    __call = function(self)
        local stream = self.stream

        local resp = stream()
        if stream.status ~= 200 then
            log_info("watch response:", resp)
            return nil, stream.status
        end

        local body = decode_json(resp)
        if not body then
            log_info("decode json failed:", resp)
            report_failure(self.endpoint.http_host)
            return nil, "decode json failed"
        end

        if body.error then
            log_info("watch return err:", body.error)
            return nil, body.error, stream
        end

        local events = body.result and body.result.events

        if not events then
            return body, nil, stream
        end

        for _, ev in ipairs(events) do
            ev.kv.value = ev.kv.value and decode_base64(ev.kv.value) -- DELETE not have value
            ev.kv.key = decode_base64(ev.kv.key)
            ev.type = ev.type or "PUT"

            if ev.prev_kv then
                ev.prev_kv.value = ev.prev_kv.value and decode_base64(ev.prev_kv.value)
                ev.prev_kv.key = decode_base64(ev.prev_kv.key)
            end
        end

        return body, nil, stream
    end,
    __close = function(self)
		if self.stream then
			self.stream:close()
		end
    end,
}

local function watch(self, key, attr)
    if type(key) ~= "string" then
        return nil, "key must be string"
    end

    if #key == 0 then
        key = str_char(0)
    end

    key = encode_base64(key)

    local range_end
    if attr.range_end then
        range_end = encode_base64(attr.range_end)
    end

    local prev_kv
    if attr.prev_kv then
        prev_kv = attr.prev_kv and true or false
    end

    local start_revision
    if attr.start_revision then
        start_revision = attr.start_revision and attr.start_revision or 0
    end

    local watch_id
    if attr.watch_id then
        watch_id = attr.watch_id and attr.watch_id or 0
    end

    local progress_notify
    if attr.progress_notify then
        progress_notify = attr.progress_notify and true or false
    end

    local fragment
    if attr.fragment then
        fragment = attr.fragment and true or false
    end

    local filters
    if attr.filters then
        filters = attr.filters and attr.filters or 0
    end

    local need_cancel
    if attr.need_cancel then
        need_cancel = attr.need_cancel and true or false
    end

    local body = {
        create_request = {
            key = key,
            range_end = range_end,
            prev_kv = prev_kv,
            start_revision = start_revision,
            watch_id = watch_id,
            progress_notify = progress_notify,
            fragment = fragment,
            filters = filters,
        },
    }

    local watch_stream, err = _post_stream(self, URL_WATCH, body, attr and attr.timeout or self.timeout)
	if err then
		return setmetatable({}, watch_mt), err
	end
    return setmetatable(watch_stream, watch_mt)
end

function _M.watch(self, key, opts)
    opts = opts or {}
    opts.range_end = nil
    return watch(self, key, opts)
end

function _M.watchdir(self, key, opts)
    opts = opts or {}
    opts.range_end = get_range_end(key)
    return watch(self, key, opts)
end

return _M
