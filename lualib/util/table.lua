local M = {}

-- Save copied tables in `copies`, indexed by original table.
function M.deepcopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            for orig_key, orig_value in next, orig, nil do
                copy[M.deepcopy(orig_key, copies)] = M.deepcopy(orig_value, copies)
            end
            copies[orig] = copy
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function M.keys(data)
    local copy = {}
    local idx = 1
    for k,_ in pairs(data) do
        copy[idx] = k
        idx = idx + 1
        --table.insert(copy, k)
    end
    return copy
end

function M.size(data)
    if type(data) ~= 'table' then
        return 0
    end
    local cnt = 0
    for _ in pairs(data) do
        cnt = cnt + 1
    end
    return cnt
end

-- not deep copy
function M.values(data)
    local copy = {}
    local idx = 1
    for _,v in pairs(data) do
        copy[idx] = v
        idx = idx + 1
    end
    return copy
end

function M.clear(t)
    for k,_ in pairs(t) do
        t[k] = nil
    end
end

function M.merge(t1, t2)
    for k,v in pairs(t2) do
        t1[k] = v
    end
end

---------------------------------
-- table.tostring(tbl)
---------------------------------
-- fork from http://lua-users.org/wiki/TableUtils
local gsub = string.gsub
local match = string.match
local function append_result(result, ...)
    local n = select('#', ...)
    for i=1,n  do
        result.i = result.i + 1
        result[result.i] = select(i, ...)
    end
end

local function val_to_str(v, result)
    local tp = type(v)
    if "string" == tp then
        v = gsub(v, "\n", "\\n")
        if match(gsub(v, "[^'\"]", ""), '^"+$') then
            append_result(result, "'")
            append_result(result, v)
            append_result(result, "'")
        else
            append_result(result, '"')
            v = gsub(v, '"', '\\"')
            append_result(result, v)
            append_result(result, '"')
        end
    elseif "table" == tp then
        M.tostring_tbl(v, result)
    elseif "function" == tp then
        append_result(result, '"', tostring(v), '"')
    else
        append_result(result, tostring(v))
    end
end

local function key_to_str(k, result)
    if "string" == type(k) and match(k, "^[_%a][_%a%d]*$") then
        append_result(result, k)
    else
        append_result(result, "[")
        val_to_str(k, result)
        append_result(result, "]")
    end
end

local MAX_STR_TBL_CNT = 1024*1024 -- result has 1M element
M.tostring_tbl = function (tbl, result)
    if not result.i then
        result.i = 0
    end
    append_result(result, "{")
    for k,v in pairs(tbl) do
        if result.i > MAX_STR_TBL_CNT then
            break
        end
        key_to_str(k, result)
        append_result(result, "=")
        val_to_str(v, result)
        append_result(result, ",")
    end
    append_result(result, "}")
end

M.concat_tostring_tbl = function (result)
    result.i = nil
    return table.concat(result, "")
end

M.tostring = function(tbl)
    local result = {}
    result.i = 0
    val_to_str(tbl, result)
    return M.concat_tostring_tbl(result)
end

M.in_array = function (tbl, check_value)
    for k,v in pairs(tbl) do
        if v == check_value then
            return k
        end
    end
end

return M
